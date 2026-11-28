// Text helpers the form/wizard emitters share.

import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';

/// [raw] with `<<name>>` replaced from [vars] and `«Symbol»` references.
String tpl(String raw, Map<String, String> vars) {
  final text = raw.replaceAllMapped(RegExp(r'<<(\w+)>>'), (m) {
    final v = vars[m[1]];
    if (v == null) throw StateError('template variable <<${m[1]}>> unset');
    return v;
  });
  return templateRefs(text);
}

/// `/// ` lines for [doc] at [indent], ending in a newline; nothing for null.
String docLines(String? doc, {String indent = ''}) {
  if (doc == null) return '';
  return '${doc.trimRight().split('\n').map((l) => l.isEmpty ? '$indent///' : '$indent/// $l').join('\n')}\n';
}

/// `// ` lines for [text] at [indent], ending in a newline.
String commentLines(String text, {String indent = ''}) =>
    '${text.trimRight().split('\n').map((l) => l.isEmpty ? '$indent//' : '$indent// $l').join('\n')}\n';

/// Word-wraps [text] to [width] columns (greedy), keeping blank lines.
String wrap(String text, int width) => text
    .split('\n')
    .map((para) {
      if (para.isEmpty) return para;
      final lines = <String>[];
      var line = '';
      for (final w in para.split(' ')) {
        if (line.isEmpty) {
          line = w;
        } else if (line.length + 1 + w.length <= width) {
          line = '$line $w';
        } else {
          lines.add(line);
          line = w;
        }
      }
      lines.add(line);
      return lines.join('\n');
    })
    .join('\n');

/// [code] with every type of `options.types` it names turned into a
/// reference, so mcgen writes its import. Use it on Dart code only: a doc
/// comment that mentions a type must not import it.
String refs(FwModel m, String code) {
  if (m.types.isEmpty) return code;
  final names = m.types.keys.toList()..sort((a, b) => b.length - a.length);
  final pattern = RegExp(
    r"(?<![A-Za-z0-9_$.'])(" + names.join('|') + r")(?![A-Za-z0-9_$'])",
  );
  return code.replaceAllMapped(pattern, (x) => ref(x[1]!));
}

/// A field or parameter list, one per line, a blank line before every
/// documented one but the first (the shape the exemplars' hand-written lists
/// have, which `dart format` keeps).
String documented(List<(String? doc, String line)> items) {
  final b = StringBuffer();
  for (final (i, (doc, line)) in items.indexed) {
    if (doc != null && i > 0) b.writeln();
    b
      ..write(docLines(doc))
      ..writeln(line);
  }
  return b.toString().trimRight();
}
