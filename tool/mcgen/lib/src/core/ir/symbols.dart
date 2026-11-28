// The symbol table (plan 02 section 2.4): every emitted declaration registers
// the library that owns it; references resolve through it to imports.

import 'package:mcgen/src/core/ir/code.dart';

/// Names `dart:core` exports: a reference to one needs no import.
const dartCoreNames = {
  'ArgumentError',
  'BigInt',
  'Comparable',
  'DateTime',
  'Deprecated',
  'Duration',
  'Enum',
  'Error',
  'Exception',
  'FormatException',
  'Function',
  'Future',
  'Invocation',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'MapEntry',
  'Never',
  'Null',
  'Object',
  'Pattern',
  'Record',
  'RegExp',
  'Runes',
  'Set',
  'StackTrace',
  'StateError',
  'Stopwatch',
  'Stream',
  'String',
  'StringBuffer',
  'Symbol',
  'Type',
  'UnimplementedError',
  'UnsupportedError',
  'Uri',
  'bool',
  'deprecated',
  'double',
  'dynamic',
  'identical',
  'int',
  'num',
  'override',
  'pragma',
  'print',
  'void',
};

/// Where a symbol lives.
class SymbolDef {
  const SymbolDef(this.name, this.library, {required this.external});

  final String name;

  /// The owning library's URI: `package:x/src/y.dart` or `dart:async`.
  final String library;

  /// Registered as a dependency's symbol rather than emitted here.
  final bool external;

  /// The package of [library], or null for `dart:` libraries.
  String? get package => packageOf(library);
}

/// Whether [uri] names a test file of the module being emitted
/// (`path:test/...`, see `DartLibrary.symbolUri`).
bool isPathUri(String uri) => uri.startsWith('path:');

/// The package of a `package:` [uri], or null.
String? packageOf(String uri) {
  if (!uri.startsWith('package:')) return null;
  final rest = uri.substring('package:'.length);
  final slash = rest.indexOf('/');
  return slash < 0 ? null : rest.substring(0, slash);
}

/// Thrown for an unknown, ambiguous or duplicate symbol.
class SymbolError implements Exception {
  SymbolError(this.message);

  final String message;

  @override
  String toString() => message;
}

class SymbolTable {
  final _byName = <String, List<SymbolDef>>{};

  /// Registers a declaration emitted into [library].
  void define(String name, String library) =>
      _add(SymbolDef(name, library, external: false));

  /// Registers a dependency's public symbol, e.g. `external('Money',
  /// 'package:mc_formatters/mc_formatters.dart')`.
  void external(String name, String library) =>
      _add(SymbolDef(name, library, external: true));

  void _add(SymbolDef d) {
    if (dartCoreNames.contains(d.name)) {
      throw SymbolError(
        '"${d.name}" is a dart:core name and cannot be redefined',
      );
    }
    final defs = _byName.putIfAbsent(d.name, () => []);
    if (defs.any((e) => e.library == d.library)) {
      throw SymbolError('"${d.name}" is already defined in ${d.library}');
    }
    defs.add(d);
  }

  /// Every definition of [name].
  List<SymbolDef> lookup(String name) =>
      List.unmodifiable(_byName[name] ?? const []);

  /// The library [r] refers to, or null for a `dart:core` name.
  ///
  /// [fromTest] is whether the referring library is a test file. A `lib/`
  /// file never sees test files' declarations; a test file prefers its
  /// module's own test declarations, so a test util that re-declares a
  /// `lib/src` key is not ambiguous for steps (they never import `src/`).
  String? resolve(SymbolRef r, {bool fromTest = false}) {
    if (r.from != null) {
      final defs = _byName[r.name] ?? const [];
      if (defs.isNotEmpty && !defs.any((d) => d.library == r.from)) {
        throw SymbolError(
          '"${r.name}" is not defined in ${r.from} (defined in ${defs.map((d) => d.library).join(', ')})',
        );
      }
      return r.from;
    }
    var defs = [
      for (final d in _byName[r.name] ?? const <SymbolDef>[])
        if (fromTest || !isPathUri(d.library)) d,
    ];
    if (fromTest && defs.length > 1) {
      final local = [
        for (final d in defs)
          if (isPathUri(d.library)) d,
      ];
      if (local.length == 1) defs = local;
    }
    if (defs.isEmpty) {
      if (dartCoreNames.contains(r.name)) return null;
      throw SymbolError(
        'unknown symbol "${r.name}": no emitted declaration or registered dependency defines it',
      );
    }
    if (defs.length > 1) {
      throw SymbolError(
        'ambiguous symbol "${r.name}": defined in ${defs.map((d) => d.library).join(' and ')}; pin it with ref(..., from:)',
      );
    }
    return defs.single.library;
  }
}
