// The round-trip golden (plan 02 KD1): `mcgen gen` on an exemplar's spec
// must reproduce the exemplar byte for byte, apart from keep-region bodies
// and the mcgen header (exemplars are hand-written, so they carry neither).
// P2-04 to P2-07 call [compareToExemplar] from their archetype's golden test.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mcgen/src/core/generator.dart';
import 'package:mcgen/src/core/keep.dart';
import 'package:path/path.dart' as p;

/// Paths an exemplar has that are never generator output: tool/ide_sync and
/// `pub get` artefacts (all git-ignored) and the manifest.
const defaultExemplarIgnores = [
  '.mcgen/**',
  '**/*.g.dart',
  '**/*.freezed.dart',
  'lib/src/di/*.config.dart',
  '**/*.injectable.json',
  'lib/src/l10n/*_l10n.dart',
  'lib/src/l10n/*_l10n_*.dart',
];

class TreeDiff {
  const TreeDiff(this.onlyGenerated, this.onlyExemplar, this.differing);

  final List<String> onlyGenerated;
  final List<String> onlyExemplar;

  /// Path -> the first differing line, as `line N: generated | exemplar`.
  final Map<String, String> differing;

  bool get identical =>
      onlyGenerated.isEmpty && onlyExemplar.isEmpty && differing.isEmpty;

  @override
  String toString() => [
    for (final f in onlyGenerated) 'only generated: $f',
    for (final f in onlyExemplar) 'only in the exemplar: $f',
    for (final e in differing.entries) 'differs: ${e.key}: ${e.value}',
  ].join('\n');
}

/// Lists [dir]'s files (module-relative, sorted), skipping dot-directories
/// and anything matching [ignore].
List<String> listTree(String dir, {List<String> ignore = const []}) {
  final globs = [for (final g in ignore) globToRegExp(g)];
  final out = <String>[];
  void walk(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      final name = p.basename(e.path);
      final rel = p.posix.joinAll(p.split(p.relative(e.path, from: dir)));
      if (e is Directory) {
        if (name == '.dart_tool' || name == 'build') continue;
        walk(e);
      } else if (e is File && !globs.any((g) => g.hasMatch(rel))) {
        out.add(rel);
      }
    }
  }

  walk(Directory(dir));
  out.sort();
  return out;
}

/// sha256 over every file of [dir] (path and bytes, sorted by path).
String hashTree(String dir, {List<String> ignore = const []}) {
  final b = BytesBuilder();
  for (final rel in listTree(dir, ignore: ignore)) {
    b
      ..add(utf8.encode(rel))
      ..addByte(0)
      ..add(File(p.join(dir, rel)).readAsBytesSync())
      ..addByte(0);
  }
  return sha256.convert(b.takeBytes()).toString();
}

/// Drops the mcgen header (either side may have it: exemplars are
/// hand-written, other references generated) and keep-region bodies.
String _normalise(String path, String content) {
  var text = content;
  final header = headerFor(path);
  if (header != null && text.startsWith(header)) {
    text = text.substring(header.length);
  }
  final prefix = keepPrefixFor(path);
  return prefix == null ? text : stripKeepRegions(text, prefix);
}

/// Compares [gen] with the exemplar in [exemplarDir]. Exemplar files that
/// match [ignore] are not expected from the generator.
TreeDiff compareToExemplar(
  GeneratedModule gen,
  String exemplarDir, {
  List<String> ignore = defaultExemplarIgnores,
}) {
  final exemplar = listTree(exemplarDir, ignore: ignore).toSet();
  final generated = gen.files.keys.toSet();
  final differing = <String, String>{};
  for (final path in (generated.intersection(exemplar).toList()..sort())) {
    final a = _normalise(path, gen.files[path]!.content);
    final b = _normalise(
      path,
      File(p.join(exemplarDir, path)).readAsStringSync(),
    );
    if (a == b) continue;
    final la = a.split('\n');
    final lb = b.split('\n');
    var i = 0;
    while (i < la.length && i < lb.length && la[i] == lb[i]) {
      i++;
    }
    differing[path] =
        'line ${i + 1}: ${i < la.length ? la[i] : '<eof>'} | ${i < lb.length ? lb[i] : '<eof>'}';
  }
  return TreeDiff(
    generated.difference(exemplar).toList()..sort(),
    exemplar.difference(generated).toList()..sort(),
    differing,
  );
}
