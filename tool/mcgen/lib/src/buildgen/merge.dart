// Merging a generated BUILD file with the one on disk (ADR-0018).
//
// buildgen writes every statement itself, in its own order. From the file on
// disk it carries over only what a human owns:
//   - the prose above each statement (comments and blank lines, by key);
//   - a statement's own text, comments included, when its code tokens equal
//     the generated statement's (so a comment inside a target survives);
//   - list items marked `# keep` (Gazelle's convention);
//   - the hand region at the end (`# mcgen:keep build` ... `# mcgen:end
//     build`), whose statements replace the generated ones of the same key.
// Everything else is regenerated, so `--check` fails on any code drift.

import 'package:mcgen/src/buildgen/starlark.dart';

/// Labels in BUILD order: the package's own targets (`:x`) first, then by
/// code unit (`//...` before `@...`).
int compareLabels(String a, String b) {
  final la = a.startsWith(':');
  final lb = b.startsWith(':');
  if (la != lb) return la ? -1 : 1;
  return a.compareTo(b);
}

class BuildWriter {
  BuildWriter(this.existing);

  final BuildFile? existing;
  final _out = StringBuffer();
  final _keptNow = <String, Set<String>>{};
  var _first = true;

  /// Hand-region keys buildgen skipped: the statements it would have written.
  final overridden = <String>[];

  Set<String> _keptOf(String key, String attr) =>
      existing?[key]?.kept[attr] ?? const {};

  /// [derived] minus [minus], plus the items `# keep` keeps in [attr] of
  /// statement [key], sorted. Remembers the kept ones for [listVar] and
  /// [listAttr].
  List<String> kept(
    String key,
    String attr,
    Set<String> derived, {
    Set<String> minus = const {},
  }) {
    final keep = _keptOf(key, attr);
    _keptNow['$key/$attr'] = keep;
    return {...derived.difference(minus), ...keep}.toList()
      ..sort(compareLabels);
  }

  String _item(String key, String attr, String item) {
    final keep = _keptNow['$key/$attr'] ?? const {};
    return keep.contains(item) ? '"$item",  $keepComment' : '"$item",';
  }

  /// `NAME = [` one item per line `]`.
  String listVar(String name, List<String> items, {String? keptOf}) {
    final b = StringBuffer('$name = [\n');
    for (final i in items) {
      b.writeln(
        '    ${keptOf == null ? '"$i",' : _item(keptOf, name, i)}',
      );
    }
    b.writeln(']');
    return '$b';
  }

  /// `    attr = [...],` inside a call: inline for one plain item.
  String listAttr(
    String attr,
    List<String> items, {
    String? keptOf,
    String prefix = '',
    String suffix = '',
  }) {
    final keep = keptOf == null
        ? const <String>{}
        : _keptNow['$keptOf/$attr'] ?? const {};
    if (items.length == 1 && !keep.contains(items.single)) {
      return '    $attr = $prefix["${items.single}"]$suffix,\n';
    }
    final b = StringBuffer('    $attr = $prefix[\n');
    for (final i in items) {
      b.writeln('        ${keptOf == null ? '"$i",' : _item(keptOf, attr, i)}');
    }
    b.writeln('    ]$suffix,');
    return '$b';
  }

  /// Adds statement [key]. [lead] is the prose for a statement the file on
  /// disk does not have (default: one blank line).
  void add(String key, String text, {String lead = '\n'}) {
    final file = existing;
    if (file != null && file.handKeys.contains(key)) {
      overridden.add(key);
      return;
    }
    final old = file?[key];
    final gen = BuildFile.parse(text).statements;
    if (gen.length != 1 || gen.single.key != key) {
      throw StateError(
        'buildgen wrote ${gen.map((s) => s.key).toList()} for $key:\n$text',
      );
    }
    final same = old != null && old.sameCode(gen.single);
    final l = old?.lead ?? (_first ? lead : lead);
    _out
      ..write(l)
      ..write(same ? old.text : text);
    _first = false;
  }

  /// The file: the statements, then the hand region if the file has one.
  String finish() {
    final file = existing;
    final hand = file?.hand;
    if (hand == null) return '$_out${file?.trailer ?? ''}';
    return '$_out${file!.trailer.isEmpty ? '\n' : file.trailer}'
        '$handRegionStart\n$hand\n$handRegionEnd\n';
  }
}
