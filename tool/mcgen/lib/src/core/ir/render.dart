// The import resolver and the Dart renderer (plan 02 section 2.4).
//
// Imports are exactly the libraries the code references: each reference
// resolves through the symbol table, the library's own URI is dropped, and
// what is left is written as `package:` (or `dart:`) imports, sorted by code
// unit within each `directives_ordering` section.

import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/ir/symbols.dart';
import 'package:path/path.dart' as p;

/// A library after resolution: what it imports and re-exports.
class ResolvedLibrary {
  const ResolvedLibrary(this.library, this.imports, this.exports);

  final DartLibrary library;

  /// Sorted URIs: `dart:`, `package:` and `path:` (another test file of the
  /// module, written as a relative import).
  final List<String> imports;

  /// Owning URI -> sorted names to `show`.
  final Map<String, List<String>> exports;

  /// Packages this library uses (imports and exports), sorted.
  List<String> get packages {
    final out = <String>{
      for (final u in [...imports, ...exports.keys]) ?packageOf(u),
    }.toList()..sort();
    return out;
  }
}

/// Resolves [lib]'s references. [selfUri] is its own `package:` URI, if any.
/// Throws [SymbolError] naming the library.
ResolvedLibrary resolveLibrary(
  DartLibrary lib,
  SymbolTable table, {
  String? selfUri,
  List<DartLibrary> parts = const [],
}) {
  final fromTest = !lib.path.startsWith('lib/');
  final own = selfUri ?? 'path:${lib.path}';
  final imports = <String>{
    ...lib.imports,
    for (final part in parts) ...part.imports,
  };
  for (final code in [
    ...lib.codes,
    for (final part in parts) ...part.codes,
  ]) {
    for (final r in code.refs) {
      final String? uri;
      try {
        uri = table.resolve(r, fromTest: fromTest);
      } on SymbolError catch (e) {
        throw SymbolError('${lib.path}: ${e.message}');
      }
      if (uri != null && uri != own && uri != 'dart:core') imports.add(uri);
    }
  }
  if (!fromTest && imports.any(isPathUri)) {
    throw SymbolError(
      '${lib.path}: a lib/ file cannot import a test file (${imports.where(isPathUri).join(', ')})',
    );
  }
  final exports = <String, Set<String>>{};
  for (final e in lib.exports) {
    for (final name in e.symbols) {
      final String? uri;
      try {
        uri = table.resolve(SymbolRef(name));
      } on SymbolError catch (err) {
        throw SymbolError('${lib.path}: export: ${err.message}');
      }
      if (uri == null) {
        throw SymbolError('${lib.path}: cannot export dart:core "$name"');
      }
      exports.putIfAbsent(uri, () => {}).add(name);
    }
  }
  final sortedExports = {
    for (final u in (exports.keys.toList()..sort()))
      u: (exports[u]!.toList()..sort()),
  };
  return ResolvedLibrary(lib, imports.toList()..sort(), sortedExports);
}

/// Renders a resolved library as (unformatted) Dart.
String renderLibrary(ResolvedLibrary r) {
  final lib = r.library;
  final b = StringBuffer();
  if (lib.preamble != null) b.write(lib.preamble);
  if (lib.partOf != null) {
    b
      ..writeln("part of '${lib.partOf}';")
      ..writeln();
    b.write([for (final d in lib.decls) _decl(d)].join('\n\n'));
    return '${b.toString().trimRight()}\n';
  }
  final sections = <List<String>>[
    [
      for (final u in r.imports)
        if (u.startsWith('dart:')) "import '$u';",
    ],
    [
      for (final u in r.imports)
        if (!u.startsWith('dart:') && !isPathUri(u)) "import '$u';",
    ],
    [
      for (final u in r.imports)
        if (isPathUri(u))
          "import '${p.posix.relative(u.substring(5), from: p.posix.dirname(lib.path))}';",
    ],
    [
      for (final e in r.exports.entries)
        "export '${e.key}' show ${e.value.join(', ')};",
    ],
    [for (final p in lib.parts) "part '$p';"],
  ].where((s) => s.isNotEmpty).toList();
  for (final s in sections) {
    b.writeln(s.join('\n'));
    b.writeln();
  }
  final decls = [for (final d in lib.decls) _decl(d)];
  b.write(decls.join('\n\n'));
  final out = b.toString().trimRight();
  return '$out\n';
}

String _doc(String? doc) {
  if (doc == null) return '';
  return '${doc.trimRight().split('\n').map((l) => l.isEmpty ? '///' : '/// $l').join('\n')}\n';
}

String _annotations(List<Code> a) => a.map((c) => '${c.render()}\n').join();

String _prefix(Annotated a) => '${_doc(a.doc)}${_annotations(a.annotations)}';

String _list(String keyword, List<Code> types) =>
    types.isEmpty ? '' : ' $keyword ${types.map((t) => t.render()).join(', ')}';

String _body(Body body) {
  final b = StringBuffer('{\n');
  for (final s in body.stmts) {
    switch (s) {
      case CodeStmt(:final code):
        b.writeln(code.render());
      case Keep(:final id, :final defaults):
        b.writeln('// mcgen:keep $id');
        for (final c in defaults) {
          b.writeln(c.render());
        }
        b.writeln('// mcgen:end $id');
    }
  }
  b.write('}');
  return b.toString();
}

String _callable(Code signature, Body? body, Code? arrow) {
  final sig = signature.render();
  if (body != null) return '$sig ${_body(body)}';
  if (arrow != null) return '$sig => ${arrow.render()};';
  return '$sig;';
}

String _member(Member m) => switch (m) {
  RawMember(:final code) => '${_prefix(m)}${code.render()}',
  Method(:final signature, :final body, :final arrow) =>
    '${_prefix(m)}${_callable(signature, body, arrow)}',
};

String _members(List<Member> members) => members.map(_member).join('\n\n');

String _decl(Decl d) => switch (d) {
  ClassDecl() =>
    '${_prefix(d)}${d.modifiers.isEmpty ? '' : '${d.modifiers} '}class ${d.name}'
        '${d.typeParams?.render() ?? ''}'
        '${d.superclass == null ? '' : ' extends ${d.superclass!.render()}'}'
        '${_list('with', d.mixins)}${_list('implements', d.interfaces)}'
        ' {\n${_members(d.members)}\n}',
  EnumDecl() =>
    '${_prefix(d)}enum ${d.name}${_list('implements', d.interfaces)} {\n'
        '${d.values.map((v) => '${_prefix(v)}${v.name}${v.args == null ? '' : '(${v.args!.render()})'}').join(',\n')}'
        '${d.members.isEmpty ? '' : ';\n\n${_members(d.members)}'}\n}',
  ExtensionTypeDecl() =>
    '${_prefix(d)}extension type ${d.isConst ? 'const ' : ''}${d.name}'
        '(${d.representation.render()})${_list('implements', d.interfaces)}'
        ' {${d.members.isEmpty ? '' : '\n${_members(d.members)}\n'}}',
  FunctionDecl(:final signature, :final body, :final arrow) =>
    '${_prefix(d)}${_callable(signature, body, arrow)}',
  RawDecl(:final code) => '${_prefix(d)}${code.render()}',
};
