// Text helpers the dashboard emitters share. The shared ones (`tpl`,
// `docLines`, `commentLines`, `keepRegion`) come from the list-detail
// helpers, as the other archetypes use them.

import 'package:mcgen/src/core/brick.dart';
import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/emit.dart';

export 'package:mcgen/src/emit/feature_list_detail/common.dart'
    show commentLines, docLines, keepRegion;

/// [raw] with `<<name>>` replaced from [vars]. A Dart generic that ends a
/// `<<` pair (`on<<<Event>>>`) works: the match is leftmost.
String tpl(String raw, Map<String, String> vars) =>
    raw.replaceAllMapped(RegExp(r'<<(\w+)>>'), (m) {
      final v = vars[m[1]];
      if (v == null) throw StateError('template variable <<${m[1]}>> unset');
      return v;
    });

/// A directive block: the `dart:` imports, a blank line, then the `package:`
/// imports, each section sorted by code unit (`directives_ordering`).
String imports(Iterable<String> uris) {
  final all = uris.toSet().toList()..sort();
  final dart = [
    for (final u in all)
      if (u.startsWith('dart:')) "import '$u';",
  ];
  final pkg = [
    for (final u in all)
      if (!u.startsWith('dart:')) "import '$u';",
  ];
  return [
    if (dart.isNotEmpty) dart.join('\n'),
    if (pkg.isNotEmpty) pkg.join('\n'),
  ].join('\n\n');
}

/// `/// ` lines of [text] at [indent], ending in a newline; nothing for an
/// empty text.
String docBlock(String? text, {String indent = ''}) {
  if (text == null || text.isEmpty) return '';
  return '${text.trimRight().split('\n').map((l) => l.isEmpty ? '$indent///' : '$indent/// $l').join('\n')}\n';
}

/// The context the emitters write into: [EmitContext] plus a record of every
/// file's text, so `pubspec.yaml`'s dependencies can be read back from the
/// imports of what was emitted.
class Out {
  Out(this._ctx);

  final EmitContext _ctx;
  final _texts = <String, String>{};

  BrickSet get bricks => _ctx.bricks;
  PackageCatalog get packages => _ctx.packages;
  McgenConfig get config => _ctx.config;

  void file(String path, String content, {bool owned = false}) {
    _texts[path] = content;
    _ctx.file(path, content, owned: owned);
  }

  void deferred(String path, Deferred build) => _ctx.deferred(path, build);

  /// The text of every emitted file whose path satisfies [where].
  Iterable<String> texts(bool Function(String path) where) => [
    for (final e in _texts.entries)
      if (where(e.key)) e.value,
  ];
}
