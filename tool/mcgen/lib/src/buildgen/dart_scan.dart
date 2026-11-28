// What buildgen and wire read from a package's Dart files without an
// analyzer: directives (import, export, part) and a few annotations, by
// regular expression over the text. Directives come before declarations and
// are one per statement, so this is exact for the repo's formatted code.

import 'dart:io';

import 'package:path/path.dart' as p;

final _directive = RegExp(
  r'''^\s*(import|export|part)\s+(?:'([^']+)'|"([^"]+)")''',
  multiLine: true,
);

/// One Dart file of a package.
class DartFile {
  DartFile(this.path, this.text) {
    for (final m in _directive.allMatches(text)) {
      final uri = m.group(2) ?? m.group(3)!;
      switch (m.group(1)) {
        case 'part':
          // `part of` is a directive of a part file, not a part.
          if (!text.substring(m.start, m.end).contains('part of')) {
            parts.add(uri);
          }
        default:
          imports.add(uri);
      }
    }
  }

  /// Package-relative posix path (`lib/src/x.dart`).
  final String path;
  final String text;

  /// Import and export URIs, in file order.
  final List<String> imports = [];

  /// Part URIs (`x.freezed.dart`).
  final List<String> parts = [];

  /// The packages its `package:` imports and exports name.
  Set<String> get packages => {
    for (final u in imports)
      if (u.startsWith('package:')) u.substring(8).split('/').first,
  };

  bool get isPartFile => RegExp(r'^\s*part of\b', multiLine: true).hasMatch(text);

  bool get hasFreezed => parts.any((x) => x.endsWith('.freezed.dart'));

  /// A `.g.dart` part: json_serializable or retrofit output.
  bool get hasG => parts.any((x) => x.endsWith('.g.dart'));

  bool get isRetrofit => RegExp(r'^@RestApi\b', multiLine: true).hasMatch(text);

  /// An injectable class or module (what an injectable shard reads).
  bool get isInjectable => RegExp(
    r'^\s*@(injectable|lazySingleton|singleton|module|Injectable\(|LazySingleton\(|Singleton\()',
    multiLine: true,
  ).hasMatch(text);

  /// Whether it imports a file under `test/feature/util/` (relatively or by
  /// path).
  bool get importsTestUtil => imports.any(
    (u) => !u.startsWith('package:') && u.contains('feature/util/'),
  );
}

/// The generated files `tool/ide_sync` writes beside the sources
/// (`MC_GENERATED_DART`, tool/bazel/defs.bzl), which are never sources.
bool isGeneratedDart(String rel) =>
    rel.endsWith('.g.dart') ||
    rel.endsWith('.freezed.dart') ||
    RegExp(r'^lib/src/di/[^/]+\.config\.dart$').hasMatch(rel) ||
    RegExp(r'^lib/src/l10n/[^/]*_l10n[^/]*\.dart$').hasMatch(rel);

/// Every hand-written (or mcgen-written) `.dart` file under [dir]/[sub], by
/// package-relative path, sorted by code unit.
List<DartFile> dartFiles(String dir, String sub) {
  final top = Directory(p.join(dir, sub));
  if (!top.existsSync()) return const [];
  final out = <DartFile>[];
  for (final e in top.listSync(recursive: true, followLinks: false)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final rel = p.posix.joinAll(p.split(p.relative(e.path, from: dir)));
    if (rel.split('/').any((s) => s.startsWith('.'))) continue;
    if (isGeneratedDart(rel)) continue;
    out.add(DartFile(rel, e.readAsStringSync()));
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}
