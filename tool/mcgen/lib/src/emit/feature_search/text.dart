// Text helpers the search emitters share.

import 'package:mcgen/src/emit/feature_search/model.dart';

/// [raw] with `<<name>>` replaced from [vars].
String tpl(String raw, Map<String, String> vars) =>
    raw.replaceAllMapped(RegExp(r'<<(\w+)>>'), (m) {
      final v = vars[m[1]];
      if (v == null) throw StateError('template variable <<${m[1]}>> unset');
      return v;
    });

/// `/// ` lines for [doc] at [indent], ending in a newline; nothing for null.
String docLines(String? doc, {String indent = ''}) {
  if (doc == null) return '';
  return '${doc.trimRight().split('\n').map((l) => l.isEmpty ? '$indent///' : '$indent/// $l').join('\n')}\n';
}

/// `// ` lines for [text] at [indent], ending in a newline.
String commentLines(String text, {String indent = ''}) =>
    '${text.trimRight().split('\n').map((l) => l.isEmpty ? '$indent//' : '$indent// $l').join('\n')}\n';

/// A keep region (plan 02 section 2.6) as text: [defaults] at [indent]
/// between the markers. Use it only inside a function or method body.
String keepRegion(String id, String defaults, {String indent = ''}) =>
    '$indent// mcgen:keep $id\n'
    '${defaults.split('\n').map((l) => l.isEmpty ? '' : '$indent$l').join('\n')}\n'
    '$indent// mcgen:end $id';

/// The doc comment of [slot] (the model's prose, else [fallback]) at
/// [indent], ending in a newline.
String doc(SrModel m, String slot, String fallback, {String indent = ''}) =>
    docLines(m.text(slot, fallback), indent: indent);
