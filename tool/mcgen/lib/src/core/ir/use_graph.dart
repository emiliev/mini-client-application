// The use-graph (plan 02 section 2.4): which file uses which library, and so
// which packages a module needs. The pubspec's dependencies come from here
// now; P2-08's buildgen reads the same graph for BUILD `deps`.

import 'package:mcgen/src/core/ir/render.dart';

class UseGraph {
  UseGraph(this.package, Iterable<ResolvedLibrary> libraries)
    : libraries = {for (final l in libraries) l.library.path: l};

  /// The module's own package.
  final String package;

  /// Module-relative path -> resolved library.
  final Map<String, ResolvedLibrary> libraries;

  /// File -> imported and exported URIs (sorted), for SCC and BUILD work.
  Map<String, List<String>> get edges => {
    for (final p in (libraries.keys.toList()..sort()))
      p: ({...libraries[p]!.imports, ...libraries[p]!.exports.keys}.toList()
        ..sort()),
  };

  Set<String> _packages(bool Function(String path) where) => {
    for (final l in libraries.values)
      if (where(l.library.path))
        for (final pkg in l.packages)
          if (pkg != package) pkg,
  };

  /// Packages `lib/` uses: the pubspec `dependencies` (sorted).
  List<String> get libDeps =>
      _packages((p) => p.startsWith('lib/')).toList()..sort();

  /// Packages only non-`lib/` files use: the pubspec `dev_dependencies`.
  List<String> get devDeps {
    final lib = libDeps.toSet();
    return (_packages((p) => !p.startsWith('lib/'))..removeAll(lib)).toList()
      ..sort();
  }
}
