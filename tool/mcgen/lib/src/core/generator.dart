// `mcgen gen`'s pure half: spec in, exact file bytes and manifest out.
// Nothing here touches the module directory (see writer.dart).

import 'package:mcgen/src/core/archetype.dart';
import 'package:mcgen/src/core/brick.dart';
import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/diagnostics.dart';
import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/format.dart';
import 'package:mcgen/src/core/ir/symbols.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/core/keep.dart';
import 'package:mcgen/src/core/lint.dart';
import 'package:mcgen/src/core/manifest.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/rng.dart';
import 'package:mcgen/src/core/spec/spec.dart';

/// The first line of every managed file (plan 02 section 2.6), followed by
/// one blank line. A comment, so it never counts toward D8.
const headerText =
    'Scaffolded by mcgen from mcgen.yaml; edit the spec or a keep region.';

/// The header as it appears in [path], or null for file kinds without
/// comments (JSON, ARB).
String? headerFor(String path) {
  if (path.endsWith('.dart')) return '// $headerText\n\n';
  if (path.endsWith('.yaml') ||
      path.endsWith('.yml') ||
      path.endsWith('.feature')) {
    return '# $headerText\n\n';
  }
  return null;
}

class GeneratedFile {
  const GeneratedFile(
    this.path,
    this.content, {
    required this.ownership,
    required this.keep,
  });

  final String path;
  final String content;

  /// `managed` or `owned`.
  final String ownership;

  /// Keep-region id -> hash of its default body (as rendered here).
  final Map<String, String> keep;

  String get hash => contentHash(path, content);
}

class GeneratedModule {
  const GeneratedModule(this.spec, this.files, this.manifest, this.graph);

  final ModuleSpec spec;

  /// Module-relative path -> file, sorted by code unit.
  final Map<String, GeneratedFile> files;
  final Manifest manifest;
  final UseGraph graph;
}

/// `*` matches inside one path segment, `**` across segments, and `**/`
/// zero or more whole directories.
RegExp globToRegExp(String glob) {
  final b = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        if (i + 2 < glob.length && glob[i + 2] == '/') {
          // `**/` is zero or more directories: `lib/**/*.dart` matches
          // `lib/x.dart` too.
          b.write('(?:.*/)?');
          i += 2;
        } else {
          b.write('.*');
          i++;
        }
      } else {
        b.write('[^/]*');
      }
    } else {
      b.write(RegExp.escape(c));
    }
  }
  b.write(r'$');
  return RegExp(b.toString());
}

class Generator {
  Generator({
    required this.config,
    required this.archetypes,
    required this.bricks,
    required this.formatter,
  });

  final McgenConfig config;
  final Map<String, Archetype> archetypes;
  final BrickSet bricks;
  final DartFormatter formatter;

  /// Renders [spec]. [forbidden] are absolute paths that must never appear
  /// in output (the root, the tool dir). Throws [McgenException].
  GeneratedModule generate(
    ModuleSpec spec, {
    required RepoIndex index,
    List<ModuleSpec> specs = const [],
    List<String> forbidden = const [],
  }) {
    final lint = lintSpec(
      spec,
      LintContext(
        index: index,
        config: config,
        archetypes: archetypes,
        specs: [spec, ...specs],
      ),
    );
    if (lint.isNotEmpty) throw McgenException(lint);
    final archetype = archetypes[spec.archetype]!;
    final rng = Rng.forModule(
      globalSeed: config.globalSeed,
      module: spec.module,
      seedSalt: spec.seedSalt,
    );
    final ctx = EmitContext(
      spec: spec,
      config: config,
      rng: rng,
      packages: PackageCatalog(config, index, specs: [spec, ...specs]),
      bricks: bricks,
    );
    final List<EmittedFile> emitted;
    final UseGraph graph;
    try {
      archetype.emit(ctx);
      (emitted, graph) = ctx.finish();
    } on SymbolError catch (e) {
      throw McgenException.message(spec.file, 'emit', e.message);
    } on BrickError catch (e) {
      throw McgenException.message(spec.file, 'brick', e.message);
    } on StateError catch (e) {
      throw McgenException.message(spec.file, 'emit', e.message);
    }

    final ownedGlobs = [for (final g in spec.owned) globToRegExp(g)];
    String ownershipOf(EmittedFile f) =>
        spec.ownership == Ownership.mixed &&
            (f.owned || ownedGlobs.any((g) => g.hasMatch(f.path)))
        ? 'owned'
        : 'managed';

    final withHeaders = <String, String>{};
    final ownership = <String, String>{};
    for (final f in emitted) {
      final own = ownershipOf(f);
      ownership[f.path] = own;
      final header = own == 'managed' ? headerFor(f.path) : null;
      withHeaders[f.path] = header == null ? f.content : '$header${f.content}';
    }
    final Map<String, String> formatted;
    try {
      formatted = formatter.formatAll({
        for (final e in withHeaders.entries)
          if (e.key.endsWith('.dart')) e.key: e.value,
      });
    } on FormatError catch (e) {
      throw McgenException.message(spec.file, 'format', e.message);
    }

    final problems = <Diagnostic>[];
    void problem(String message) => problems.add(
      Diagnostic(code: 'emit', message: message, file: spec.file),
    );
    final files = <String, GeneratedFile>{};
    final emittedKeep = <String>{};
    for (final path in (withHeaders.keys.toList()..sort())) {
      var content = formatted[path] ?? withHeaders[path]!;
      if (content.contains('\r')) {
        problem('$path: output contains CR; mcgen writes LF only');
      }
      if (content.isNotEmpty && !content.endsWith('\n')) content = '$content\n';
      for (final abs in forbidden) {
        // A one-character path (`/`) would match everything.
        if (abs.length > 1 && content.contains(abs)) {
          problem('$path: output contains the absolute path $abs');
        }
      }
      final prefix = keepPrefixFor(path);
      final keep = <String, String>{};
      if (prefix != null) {
        final scan = KeepScan.of(content, prefix);
        if (!scan.ok) {
          problem(
            '$path: generated keep markers are damaged: ${scan.damage.join('; ')}',
          );
        }
        for (final r in scan.regions) {
          keep[r.id] = bodyHash(r.body);
        }
        emittedKeep.addAll(scan.ids);
      }
      files[path] = GeneratedFile(
        path,
        content,
        ownership: ownership[path]!,
        keep: keep,
      );
    }
    for (final id in spec.keep) {
      if (!emittedKeep.contains(id)) {
        problem(
          'keep region "$id" is declared in the spec but no file emits it',
        );
      }
    }
    if (problems.isNotEmpty) throw McgenException(problems);

    final manifest = Manifest(
      generator: 'mcgen $mcgenVersion',
      module: spec.module,
      archetype: spec.archetype,
      ownership: spec.ownership.name,
      seed: hex64(rng.seed),
      specHash: spec.specHash,
      files: {
        for (final f in files.values)
          f.path: ManifestEntry(
            hash: f.hash,
            ownership: f.ownership,
            keep: f.keep,
          ),
      },
    );
    return GeneratedModule(spec, files, manifest, graph);
  }
}
