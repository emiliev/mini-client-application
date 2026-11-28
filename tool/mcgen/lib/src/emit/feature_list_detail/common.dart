// Helpers the list-detail emitters share.

import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/symbols.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/core/spec/types.dart';

const material = 'package:flutter/material.dart';
const widgets = 'package:flutter/widgets.dart';
const flutterTest = 'package:flutter_test/flutter_test.dart';
const dartAsync = 'dart:async';

/// [t] as Dart source, every name outside `dart:core` a reference.
String ty(TypeExpr t) {
  final name = dartCoreNames.contains(t.name) ? t.name : ref(t.name);
  final args = t.args.isEmpty ? '' : '<${t.args.map(ty).join(', ')}>';
  return '$name$args${t.nullable ? '?' : ''}';
}

/// A type name as a reference, unless it is a `dart:core` name.
String tyName(String name) => ty(TypeExpr.parse(name));

/// `/// ` lines for [doc] at [indent], or nothing.
String docLines(String? doc, {String indent = ''}) {
  if (doc == null) return '';
  return '${doc.trimRight().split('\n').map((l) => l.isEmpty ? '$indent///' : '$indent/// $l').join('\n')}\n';
}

/// `// ` lines for [text] at [indent].
String commentLines(String text, {String indent = ''}) =>
    '${text.trimRight().split('\n').map((l) => l.isEmpty ? '$indent//' : '$indent// $l').join('\n')}\n';

/// A Dart literal for a spec default.
String literal(Object? v) => switch (v) {
  null => 'null',
  bool() || int() || double() => '$v',
  String() => dartString(v),
  List() when v.isEmpty => 'const []',
  _ => throw StateError('list_detail cannot write the default $v'),
};

/// Named parameters or fields, one per line, a blank line before every
/// documented one but the first: the shape the exemplars' hand-written
/// parameter lists have, which `dart format` keeps.
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

/// The words of a camelCase name (`openCharacter` -> `open character`).
String words(String camel) => snakeCase(camel).replaceAll('_', ' ');

/// `name` -> `Named`, `title` -> `Titled`: how the test env's lookups by a
/// record's title field are named (`characterNamed`, `comicTitled`).
String participle(String field) {
  final p = pascalCase(field);
  return p.endsWith('e') ? '${p}d' : '${p}ed';
}

/// Whether [f] needs `required` as a named constructor parameter.
bool needsRequired(FieldSpec f) => !f.type.nullable && !f.hasDefault;

/// A keep region (plan 02 section 2.6) as text, for templates that write a
/// body as text: [defaults] at [indent] between the markers. Use it only
/// inside a function or method body, as the IR's `Keep` statement is.
String keepRegion(String id, String defaults, {String indent = ''}) =>
    '$indent// mcgen:keep $id\n'
    '${defaults.split('\n').map((l) => l.isEmpty ? '' : '$indent$l').join('\n')}\n'
    '$indent// mcgen:end $id';
