// `mcgen check`: drift without writing. Three kinds (plan 02 section 2.1):
// hand edits in managed files, stale manifests, keep-region damage.

import 'dart:io';

import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/generator.dart';
import 'package:mcgen/src/core/keep.dart';
import 'package:mcgen/src/core/manifest.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/writer.dart';
import 'package:path/path.dart' as p;

/// Checks the module of [gen] in [moduleDirAbs]. [gen] is the fresh render
/// of the current spec; null when the spec could not be rendered (the
/// caller reports why), in which case only the manifest is checked.
List<Drift> checkModule(
  ModuleSpec spec,
  String moduleDirAbs,
  GeneratedModule? gen,
) {
  if (spec.ownership == Ownership.ejected && !spec.exemplar) return const [];
  final rel = spec.moduleDir;
  final out = <Drift>[];
  final seen = <String>{};
  void add(String path, DriftKind kind, String detail) {
    if (seen.add('$path\u0000${kind.name}')) {
      out.add(Drift('$rel/$path', kind, detail));
    }
  }

  final mf = File(p.join(moduleDirAbs, manifestPath));
  if (!mf.existsSync()) {
    add(
      manifestPath,
      DriftKind.staleManifest,
      'missing: the module was never generated (run mcgen gen)',
    );
    return out;
  }
  final Manifest manifest;
  try {
    manifest = Manifest.decode(mf.readAsStringSync());
  } on FormatException catch (e) {
    add(manifestPath, DriftKind.staleManifest, 'malformed: ${e.message}');
    return out;
  }
  if (manifest.specHash != spec.specHash) {
    add(
      manifestPath,
      DriftKind.staleManifest,
      'the spec changed since the last gen',
    );
  }
  if (manifest.generator != 'mcgen $mcgenVersion') {
    add(
      manifestPath,
      DriftKind.staleManifest,
      'written by ${manifest.generator}; this is mcgen $mcgenVersion',
    );
  }

  // An exemplar is checked against its render (the round-trip below), not
  // against what the last gen recorded.
  for (final e
      in spec.exemplar
          ? const <MapEntry<String, ManifestEntry>>[]
          : manifest.files.entries) {
    if (e.value.ownership != 'managed') continue;
    final f = File(p.join(moduleDirAbs, e.key));
    if (!f.existsSync()) {
      // gen recreates it (nothing hand-written is lost), so it is stale,
      // not drift that would stop gen.
      add(e.key, DriftKind.staleManifest, 'deleted: gen would create it again');
      continue;
    }
    final content = f.readAsStringSync();
    final prefix = keepPrefixFor(e.key);
    if (prefix != null) {
      final scan = KeepScan.of(content, prefix);
      // Broken markers explain a missing region already; report them alone.
      final damage = scan.ok
          ? [
              for (final id in e.value.keep.keys)
                if (!scan.ids.contains(id)) 'keep region "$id" was removed',
            ]
          : [for (final d in scan.damage) '$d'];
      if (damage.isNotEmpty) {
        add(e.key, DriftKind.keepDamage, damage.join('; '));
      }
    }
    if (contentHash(e.key, content) != e.value.hash) {
      add(e.key, DriftKind.handEdit, 'edited outside keep regions');
    }
  }

  if (gen != null) {
    final plan = planWrite(gen, moduleDirAbs);
    for (final d in plan.drift) {
      final path = d.path.substring(rel.length + 1);
      add(path, d.kind, d.detail);
    }
    for (final c in plan.changes) {
      if (out.any((d) => d.path == '$rel/${c.path}')) continue;
      add(
        c.path,
        DriftKind.staleManifest,
        'out of date: gen would ${c.kind.name} it',
      );
    }
    if (plan.manifestChanged &&
        !out.any((d) => d.path == '$rel/$manifestPath')) {
      add(
        manifestPath,
        DriftKind.staleManifest,
        'out of date: gen would rewrite it',
      );
    }
  }
  out.sort();
  return out;
}
