// A small typed IR for Dart libraries (plan 02 section 2.4). It covers the
// shapes generated modules need and leaves expressions as [Code]; renderers
// write plain Dart and `dart format` does the layout.
//
// Keep regions exist only as a [Keep] statement inside a [Body], so they can
// only ever be emitted inside function and method bodies (plan 02 section 2.6).

import 'package:mcgen/src/core/ir/code.dart';

/// A statement in a body.
sealed class Stmt {
  const Stmt();
}

/// Ordinary statement text (may span lines).
class CodeStmt extends Stmt {
  const CodeStmt(this.code);

  final Code code;
}

/// A keep region: hand-owned once written. [defaults] is emitted only when
/// the region is new.
class Keep extends Stmt {
  Keep(this.id, this.defaults) {
    if (!RegExp(r'^[a-z][A-Za-z0-9_.-]*$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'not a keep-region id');
    }
  }

  final String id;
  final List<Code> defaults;
}

/// A block body.
class Body {
  const Body(this.stmts);

  final List<Stmt> stmts;

  Iterable<Code> get codes sync* {
    for (final s in stmts) {
      switch (s) {
        case CodeStmt(:final code):
          yield code;
        case Keep(:final defaults):
          yield* defaults;
      }
    }
  }

  Iterable<String> get keepIds => [
    for (final s in stmts)
      if (s is Keep) s.id,
  ];
}

/// What declarations and members share.
abstract class Annotated {
  const Annotated({this.doc, this.annotations = const []});

  /// Doc comment text (without `///`); may contain newlines.
  final String? doc;
  final List<Code> annotations;
}

sealed class Member extends Annotated {
  const Member({super.doc, super.annotations});

  Iterable<Code> get codes;

  Iterable<String> get keepIds => const [];
}

/// A field, constructor, getter or anything else written as one fragment.
class RawMember extends Member {
  const RawMember(this.code, {super.doc, super.annotations});

  final Code code;

  @override
  Iterable<Code> get codes => [code, ...annotations];
}

/// A method or getter with a [body] or an [arrow] expression (or neither,
/// for an abstract member, ending in `;`).
class Method extends Member {
  const Method(
    this.signature, {
    this.body,
    this.arrow,
    super.doc,
    super.annotations,
  });

  /// `String render()`, `Future<void> load({required int page}) async`, ...
  final Code signature;
  final Body? body;
  final Code? arrow;

  @override
  Iterable<Code> get codes => [
    signature,
    ...annotations,
    ...?body?.codes,
    ?arrow,
  ];

  @override
  Iterable<String> get keepIds => body?.keepIds ?? const [];
}

sealed class Decl extends Annotated {
  const Decl(this.name, {super.doc, super.annotations});

  /// The top-level name the declaration defines (null: defines nothing
  /// referable, e.g. a `main`).
  final String? name;

  Iterable<Code> get codes;

  Iterable<String> get keepIds => const [];
}

class ClassDecl extends Decl {
  const ClassDecl(
    String super.name, {
    this.modifiers = '',
    this.typeParams,
    this.superclass,
    this.mixins = const [],
    this.interfaces = const [],
    this.members = const [],
    super.doc,
    super.annotations,
  });

  /// `abstract`, `final`, `sealed`, `abstract interface`, `mixin`, ...
  final String modifiers;
  final Code? typeParams;
  final Code? superclass;
  final List<Code> mixins;
  final List<Code> interfaces;
  final List<Member> members;

  @override
  Iterable<Code> get codes => [
    ...annotations,
    ?typeParams,
    ?superclass,
    ...mixins,
    ...interfaces,
    for (final m in members) ...m.codes,
  ];

  @override
  Iterable<String> get keepIds => [for (final m in members) ...m.keepIds];
}

class EnumValue extends Annotated {
  const EnumValue(this.name, {this.args, super.doc, super.annotations});

  final String name;

  /// Constructor arguments, without parentheses.
  final Code? args;
}

class EnumDecl extends Decl {
  const EnumDecl(
    String super.name,
    this.values, {
    this.interfaces = const [],
    this.members = const [],
    super.doc,
    super.annotations,
  });

  final List<EnumValue> values;
  final List<Code> interfaces;
  final List<Member> members;

  @override
  Iterable<Code> get codes => [
    ...annotations,
    ...interfaces,
    for (final v in values) ...[...v.annotations, ?v.args],
    for (final m in members) ...m.codes,
  ];

  @override
  Iterable<String> get keepIds => [for (final m in members) ...m.keepIds];
}

class ExtensionTypeDecl extends Decl {
  const ExtensionTypeDecl(
    String super.name,
    this.representation, {
    this.isConst = true,
    this.interfaces = const [],
    this.members = const [],
    super.doc,
    super.annotations,
  });

  /// `String value`.
  final Code representation;
  final bool isConst;
  final List<Code> interfaces;
  final List<Member> members;

  @override
  Iterable<Code> get codes => [
    ...annotations,
    representation,
    ...interfaces,
    for (final m in members) ...m.codes,
  ];

  @override
  Iterable<String> get keepIds => [for (final m in members) ...m.keepIds];
}

class FunctionDecl extends Decl {
  const FunctionDecl(
    String super.name,
    this.signature, {
    this.body,
    this.arrow,
    super.doc,
    super.annotations,
  });

  final Code signature;
  final Body? body;
  final Code? arrow;

  @override
  Iterable<Code> get codes => [
    ...annotations,
    signature,
    ...?body?.codes,
    ?arrow,
  ];

  @override
  Iterable<String> get keepIds => body?.keepIds ?? const [];
}

/// Escape hatch: a typedef, a top-level variable, a mixin, a comment block.
/// [name] is what it defines (registered in the symbol table), if anything.
class RawDecl extends Decl {
  const RawDecl(this.code, {String? name, super.doc, super.annotations})
    : super(name);

  final Code code;

  @override
  Iterable<Code> get codes => [...annotations, code];
}

/// One `export` directive: the symbols to re-export; the resolver finds the
/// owning libraries and writes `export '<uri>' show <names>;`.
class Exports {
  const Exports(this.symbols);

  final List<String> symbols;
}

/// One Dart file of a module.
class DartLibrary {
  DartLibrary(
    this.path, {
    this.preamble,
    this.imports = const [],
    this.exports = const [],
    this.parts = const [],
    this.partOf,
    this.decls = const [],
  }) {
    if (!path.endsWith('.dart') ||
        path.startsWith('/') ||
        path.contains('\\')) {
      throw ArgumentError.value(
        path,
        'path',
        'module-relative posix path to a .dart file',
      );
    }
  }

  /// Module-relative: `lib/src/greeting.dart`, `test/contract/x_test.dart`.
  final String path;

  /// Comment text written verbatim before the directives (include its own
  /// trailing newline or blank line).
  final String? preamble;

  /// URIs imported whatever the code references: what a keep region's
  /// hand-written body needs, which mcgen cannot see (the spec declares
  /// them), or a library used only for its generated part
  /// (`di_initializer.config.dart`).
  final List<String> imports;

  final List<Exports> exports;

  /// `part` URIs, relative (`greeting.freezed.dart`).
  final List<String> parts;

  /// For a part file: its library's URI, relative (`x_bloc.dart`). A part
  /// has no directives of its own; its references are imported by its
  /// library, and its declarations are defined there.
  final String? partOf;

  /// The module-relative path of the library this part belongs to.
  String? get partOfPath {
    final of = partOf;
    if (of == null) return null;
    final dir = path.contains('/')
        ? path.substring(0, path.lastIndexOf('/'))
        : '';
    return dir.isEmpty ? of : '$dir/$of';
  }

  final List<Decl> decls;

  /// The `package:` URI when the file is under `lib/`, else null.
  String? uriIn(String package) =>
      path.startsWith('lib/') ? 'package:$package/${path.substring(4)}' : null;

  /// The URI other libraries of the module resolve this one's declarations
  /// to: its `package:` URI under `lib/`, else `path:<module-relative path>`
  /// (a test file, which only other test files may import, relatively). A
  /// part's declarations belong to its library.
  String symbolUri(String package) {
    final at = partOfPath ?? path;
    return at.startsWith('lib/')
        ? 'package:$package/${at.substring(4)}'
        : 'path:$at';
  }

  Iterable<Code> get codes => [for (final d in decls) ...d.codes];

  Iterable<String> get keepIds => [for (final d in decls) ...d.keepIds];
}
