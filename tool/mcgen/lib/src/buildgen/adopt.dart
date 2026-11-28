// `mcgen buildgen --adopt`: brings a hand-written BUILD file into the
// canonical form without changing what it builds (T-0074, ADR-0018).
//
// Mechanical, so its result is reviewable as a diff:
//   1. Every list item the file has that buildgen would not derive gets a
//      `# keep` comment on its line (repeated until nothing changes, since a
//      kept `_TEST_DEPS` item leaves the per-target lists).
//   2. Every statement buildgen does not write, and every one whose code
//      still differs from buildgen's, moves verbatim (prose included) into
//      the hand region at the end, which overrides the generated statement
//      of the same key.
// The adopted file then regenerates to itself, and every target has the same
// attributes as before (only list order and statement order change), which
// `bazel query` proves (F-0074).

import 'package:mcgen/src/buildgen/starlark.dart';

/// [generate] renders the canonical file for a given file on disk.
String adoptBuild(String source, String Function(BuildFile existing) generate) {
  final original = {
    for (final s in BuildFile.parse(source).statements) s.key: s,
  };
  var text = source;
  for (var round = 0; round < 8; round++) {
    final file = BuildFile.parse(text);
    final gen = BuildFile.parse(generate(file));
    final marked = _markKeeps(text, file, gen);
    if (marked == text) break;
    text = marked;
  }
  final file = BuildFile.parse(text);
  final gen = BuildFile.parse(generate(file));
  final moved = <Statement>[];
  for (final s in file.statements) {
    final g = gen[s.key];
    if (g == null || g.unorderedCode != s.unorderedCode) moved.add(s);
  }
  if (moved.isEmpty) return generate(file);
  for (final s in moved) {
    if (s.key.startsWith('var:') && gen[s.key] != null) {
      throw StateError(
        'adopt: ${s.key} differs from buildgen\'s, and a variable the '
        'generated statements use cannot move to the hand region',
      );
    }
  }
  final keep = StringBuffer();
  final main = StringBuffer();
  for (final s in file.statements) {
    if (moved.contains(s)) {
      // As the file had it: no `# keep` marks in hand code.
      final o = original[s.key] ?? s;
      final lead = o.lead.replaceFirst(RegExp(r'^\n+'), '');
      keep
        ..write(keep.isEmpty ? '' : '\n')
        ..write(lead)
        ..write(o.text);
    } else {
      main
        ..write(s.lead)
        ..write(s.text);
    }
  }
  final old = file.hand;
  final body = [
    if (old != null && old.trim().isNotEmpty) old,
    '$keep'.replaceFirst(RegExp(r'\n$'), ''),
  ].join('\n\n');
  return generate(
    BuildFile.parse('$main\n$handRegionStart\n$body\n$handRegionEnd\n'),
  );
}

/// The lists buildgen merges `# keep` items into.
const _keptAttrs = {'_PURE_DEPS', '_FLUTTER_DEPS', '_TEST_DEPS', 'deps'};

/// [text] with `# keep` added to each line holding a list item of an
/// [existing] statement that [gen]'s statement of the same key lacks.
String _markKeeps(String text, BuildFile existing, BuildFile gen) {
  final lines = text.split('\n');
  final mark = <int>{};
  for (final s in existing.statements) {
    final g = gen[s.key];
    if (g == null) continue;
    final have = _itemsByAttr(g.tokens);
    for (final (attr, value, line) in _items(s.tokens)) {
      if (!_keptAttrs.contains(attr)) continue;
      if (have[attr]?.contains(value) ?? false) continue;
      if (!have.containsKey(attr)) continue;
      mark.add(line);
    }
  }
  for (final l in mark) {
    if (!lines[l].contains('#')) lines[l] = '${lines[l]}  $keepComment';
  }
  return lines.join('\n');
}

Map<String, Set<String>> _itemsByAttr(List<Token> tokens) {
  final out = <String, Set<String>>{};
  for (final (attr, value, _) in _items(tokens)) {
    (out[attr] ??= {}).add(value);
  }
  return out;
}

/// Every string inside a list or dict, with the attribute that owns the list
/// and its line.
List<(String, String, int)> _items(List<Token> tokens) {
  final out = <(String, String, int)>[];
  final owners = <String?>[];
  String? pending;
  String? assigned;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind == TokenKind.word &&
        i + 1 < tokens.length &&
        tokens[i + 1].text == '=') {
      pending = t.text;
    }
    if (t.text == '=' && pending != null) assigned = pending;
    if (t.kind == TokenKind.punct && (t.text == '[' || t.text == '{')) {
      owners.add(assigned);
    } else if (t.kind == TokenKind.punct && (t.text == ']' || t.text == '}')) {
      if (owners.isNotEmpty) owners.removeLast();
    } else if (t.kind == TokenKind.string && owners.isNotEmpty) {
      final v = t.text.substring(1, t.text.length - 1);
      out.add((owners.last ?? '', v, t.line));
    }
  }
  return out;
}
