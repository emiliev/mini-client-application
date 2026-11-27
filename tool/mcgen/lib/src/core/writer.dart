// `mcgen gen`'s writing half: ownership, keep regions and the clobber guard
// (plan 02 section 2.6). Planning reads the module directory and decides
// everything; applying only writes what the plan says. A plan with drift is
// never applied, so a refused gen writes nothing at all.

import 'dart:io';

import 'package:mcgen/src/core/generator.dart';
import 'package:mcgen/src/core/keep.dart';
import 'package:mcgen/src/core/manifest.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:path/path.dart' as p;

/// The drift kinds `gen` refuses on and `check` reports.
enum DriftKind {
  /// A managed file changed outside its keep regions (or was deleted).
  handEdit('hand-edit'),

  /// Keep markers are unbalanced, nested, renamed or removed.
  keepDamage('keep-damage'),

  /// The manifest no longer matches the spec, the generator or the files.
  staleManifest('stale-manifest'),

  /// A keep region the new output no longer has still holds code.
  orphanKeep('orphan-keep'),

  /// A file mcgen would write exists but mcgen never wrote it.
  unmanaged('unmanaged');

  const DriftKind(this.label);

  final String label;
}

class Drift implements Comparable<Drift> {
  const Drift(this.path, this.kind, this.detail);

  /// Root-relative.
  final String path;
  final DriftKind kind;
  final String detail;

  @override
  String toString() => '$path: ${kind.label}: $detail';

  @override
  int compareTo(Drift other) {
    final c = path.compareTo(other.path);
    return c != 0 ? c : kind.index.compareTo(other.kind.index);
  }
}

enum ChangeKind { create, update, delete }

class FileChange {
  const FileChange(this.path, this.kind, {this.content, this.forced});

  /// Module-relative.
  final String path;
  final ChangeKind kind;
  final String? content;

  /// Set when `--force` overrode drift: what was overridden.
  final String? forced;
}

class WritePlan {
  WritePlan({
    required this.moduleDir,
    required this.changes,
    required this.drift,
    required this.notes,
    required this.manifestText,
    required this.manifestChanged,
    this.ejected = false,
  });

  /// Root-relative module directory.
  final String moduleDir;
  final List<FileChange> changes;
  final List<Drift> drift;

  /// Informational lines (owned files left alone, ...).
  final List<String> notes;

  /// The manifest to write, or null when nothing is to be written (ejected).
  final String? manifestText;
  final bool manifestChanged;
  final bool ejected;

  /// True when gen would write nothing and nothing drifted.
  bool get clean => changes.isEmpty && drift.isEmpty && !manifestChanged;
}

String? _read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : null;
}

/// Plans writing [gen] into [moduleDirAbs] (whose root-relative name is
/// [gen.spec.moduleDir]).
WritePlan planWrite(
  GeneratedModule gen,
  String moduleDirAbs, {
  bool force = false,
}) {
  final rel = gen.spec.moduleDir;
  String at(String path) => '$rel/$path';
  if (gen.spec.ownership == Ownership.ejected) {
    return WritePlan(
      moduleDir: rel,
      changes: const [],
      drift: const [],
      notes: const ['ejected: nothing written'],
      manifestText: null,
      manifestChanged: false,
      ejected: true,
    );
  }
  final changes = <FileChange>[];
  final drift = <Drift>[];
  final notes = <String>[];
  final manifestAbs = p.join(moduleDirAbs, manifestPath);
  final oldText = _read(manifestAbs);
  Manifest? old;
  if (oldText != null) {
    try {
      old = Manifest.decode(oldText);
    } on FormatException catch (e) {
      if (!force) {
        drift.add(
          Drift(
            at(manifestPath),
            DriftKind.staleManifest,
            'malformed: ${e.message}',
          ),
        );
      }
    }
  }

  final entries = <String, ManifestEntry>{};
  for (final f in gen.files.values) {
    final abs = p.join(moduleDirAbs, f.path);
    final current = _read(abs);
    final oldEntry = old?.files[f.path];
    if (f.ownership == 'owned') {
      if (oldEntry != null && oldEntry.ownership == 'owned') {
        entries[f.path] = oldEntry;
        if (current == null) {
          notes.add('owned ${f.path} was deleted; not written again');
        }
        continue;
      }
      if (current != null) {
        notes.add('owned ${f.path} already exists; left as it is');
        continue;
      }
      changes.add(FileChange(f.path, ChangeKind.create, content: f.content));
      entries[f.path] = ManifestEntry(
        hash: f.hash,
        ownership: 'owned',
        keep: f.keep,
      );
      continue;
    }

    entries[f.path] = ManifestEntry(
      hash: f.hash,
      ownership: 'managed',
      keep: f.keep,
    );
    if (current == null) {
      changes.add(FileChange(f.path, ChangeKind.create, content: f.content));
      continue;
    }
    final reasons = <(DriftKind, String)>[];
    if (oldEntry == null || oldEntry.ownership != 'managed') {
      reasons.add((
        DriftKind.unmanaged,
        oldEntry == null
            ? 'exists, but mcgen did not write it'
            : 'was ${oldEntry.ownership}; it is managed now',
      ));
    } else if (contentHash(f.path, current) != oldEntry.hash) {
      reasons.add((DriftKind.handEdit, 'edited outside keep regions'));
    }
    var content = f.content;
    final prefix = keepPrefixFor(f.path);
    if (prefix != null) {
      final scan = KeepScan.of(current, prefix);
      if (!scan.ok) {
        reasons.add((DriftKind.keepDamage, scan.damage.join('; ')));
      } else {
        final splice = spliceKeepRegions(f.content, current, prefix);
        content = splice.content;
        if (splice.orphans.isNotEmpty) {
          reasons.add((
            DriftKind.orphanKeep,
            'keep region(s) ${splice.orphans.join(', ')} hold code but are no longer generated',
          ));
        }
      }
    }
    // Already exactly what gen would write: nothing to clobber.
    if (content == current) continue;
    if (reasons.isNotEmpty && !force) {
      for (final (k, d) in reasons) {
        drift.add(Drift(at(f.path), k, d));
      }
      continue;
    }
    changes.add(
      FileChange(
        f.path,
        ChangeKind.update,
        content: content,
        forced: reasons.isEmpty
            ? null
            : reasons.map((r) => r.$1.label).join(', '),
      ),
    );
  }

  // Files the last gen wrote that this one no longer produces.
  for (final e
      in old?.files.entries ?? const <MapEntry<String, ManifestEntry>>[]) {
    if (gen.files.containsKey(e.key)) continue;
    final current = _read(p.join(moduleDirAbs, e.key));
    if (e.value.ownership != 'managed') {
      if (current != null) {
        notes.add(
          'owned ${e.key} is no longer generated; left as it is, now unlisted',
        );
      }
      continue;
    }
    if (current == null) continue;
    if (contentHash(e.key, current) != e.value.hash && !force) {
      drift.add(
        Drift(
          at(e.key),
          DriftKind.handEdit,
          'edited outside keep regions, and no longer generated',
        ),
      );
      continue;
    }
    changes.add(
      FileChange(
        e.key,
        ChangeKind.delete,
        forced: contentHash(e.key, current) != e.value.hash
            ? DriftKind.handEdit.label
            : null,
      ),
    );
  }

  final manifest = Manifest(
    generator: gen.manifest.generator,
    module: gen.manifest.module,
    archetype: gen.manifest.archetype,
    ownership: gen.manifest.ownership,
    seed: gen.manifest.seed,
    specHash: gen.manifest.specHash,
    files: entries,
  );
  final text = manifest.encode();
  changes.sort((a, b) => a.path.compareTo(b.path));
  drift.sort();
  return WritePlan(
    moduleDir: rel,
    changes: changes,
    drift: drift,
    notes: notes,
    manifestText: text,
    manifestChanged: text != oldText,
  );
}

/// Applies [plan]. Refuses a plan with drift.
void applyPlan(WritePlan plan, String moduleDirAbs) {
  if (plan.drift.isNotEmpty) {
    throw StateError('refusing to apply a plan with drift');
  }
  for (final c in plan.changes) {
    final f = File(p.join(moduleDirAbs, c.path));
    switch (c.kind) {
      case ChangeKind.create || ChangeKind.update:
        f.parent.createSync(recursive: true);
        f.writeAsStringSync(c.content!);
      case ChangeKind.delete:
        if (f.existsSync()) f.deleteSync();
    }
  }
  if (plan.manifestChanged && plan.manifestText != null) {
    final m = File(p.join(moduleDirAbs, manifestPath));
    m.parent.createSync(recursive: true);
    m.writeAsStringSync(plan.manifestText!);
  }
}
