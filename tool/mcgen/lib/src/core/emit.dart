// What an archetype emits into, and how emitted parts become files.

import 'package:mcgen/src/core/brick.dart';
import 'package:mcgen/src/core/config.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/ir/render.dart';
import 'package:mcgen/src/core/ir/symbols.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/rng.dart';
import 'package:mcgen/src/core/spec/spec.dart';

/// How a pubspec refers to a package.
sealed class PackageSource {
  const PackageSource();
}

class FirstPartyPackage extends PackageSource {
  const FirstPartyPackage(this.tier, this.dir);

  final Tier tier;
  final String dir;
}

class ThirdPartyPackage extends PackageSource {
  const ThirdPartyPackage(this.constraint);

  final String constraint;
}

class SdkPackage extends PackageSource {
  const SdkPackage();
}

/// Package name -> source, for pubspec lines and (P2-08) BUILD labels.
class PackageCatalog {
  PackageCatalog(this.config, this.index, {List<ModuleSpec> specs = const []})
    : _specs = {for (final s in specs) s.module: s};

  final McgenConfig config;
  final RepoIndex index;
  final Map<String, ModuleSpec> _specs;

  PackageSource? lookup(String name) {
    final spec = _specs[name];
    if (spec != null) return FirstPartyPackage(spec.tier, spec.moduleDir);
    final pkgs = index.named(name);
    if (pkgs.isNotEmpty) {
      return FirstPartyPackage(pkgs.first.tier, pkgs.first.dir);
    }
    if (config.sdkPackages.contains(name)) return const SdkPackage();
    final c = config.thirdParty[name];
    return c == null ? null : ThirdPartyPackage(c);
  }

  /// The pubspec entry for [name] under `dependencies:`, without indentation:
  /// `mc_prelude: any`, `bloc: ^9.0.0`, or the two-line SDK form.
  String pubspecEntry(String name) => switch (lookup(name)) {
    FirstPartyPackage() => '$name: any',
    ThirdPartyPackage(:final constraint) => '$name: $constraint',
    SdkPackage() => '$name:\n    sdk: flutter',
    null => throw StateError(
      'package "$name" is used but unknown: add it to the spec deps or to tool/mcgen/mcgen.yaml third_party',
    ),
  };
}

/// One file before formatting and ownership handling.
class EmittedFile {
  const EmittedFile(this.path, this.content, {this.owned = false});

  final String path;
  final String content;

  /// Written once, never again (only honoured in `mixed` modules).
  final bool owned;
}

typedef Deferred = String Function(UseGraph graph);

/// The archetype's output sink.
class EmitContext {
  EmitContext({
    required this.spec,
    required this.config,
    required this.rng,
    required this.packages,
    required this.bricks,
    SymbolTable? symbols,
  }) : symbols = symbols ?? SymbolTable();

  final ModuleSpec spec;
  final McgenConfig config;

  /// The module's root stream. Fork it per concern:
  /// `ctx.rng.fork('entities').fork(entity.name)`.
  final Rng rng;
  final PackageCatalog packages;
  final BrickSet bricks;
  final SymbolTable symbols;

  final _libraries = <String, DartLibrary>{};
  final _ownedLibraries = <String>{};
  final _files = <String, EmittedFile>{};
  final _deferred = <String, (Deferred, bool)>{};

  String get package => spec.module;

  /// Adds a Dart library; its named declarations are registered as defined
  /// in it (only `lib/` files have a URI others can import).
  void library(DartLibrary lib, {bool owned = false}) {
    _claim(lib.path);
    _libraries[lib.path] = lib;
    if (owned) _ownedLibraries.add(lib.path);
    final uri = lib.uriIn(package);
    if (uri == null) return;
    for (final d in lib.decls) {
      final name = d.name;
      if (name != null) symbols.define(name, uri);
    }
  }

  /// Adds a non-Dart (or pre-rendered) file.
  void file(String path, String content, {bool owned = false}) {
    _claim(path);
    _files[path] = EmittedFile(path, content, owned: owned);
  }

  /// Renders brick [name] with [vars] and adds every file it produces.
  void brick(String name, Map<String, Object?> vars, {bool owned = false}) {
    bricks[name]
        .render(vars)
        .forEach((path, content) => file(path, content, owned: owned));
  }

  /// Adds [path], built once every library is resolved (a pubspec needs the
  /// use-graph's dependencies).
  void deferred(String path, Deferred build, {bool owned = false}) {
    _claim(path);
    _deferred[path] = (build, owned);
  }

  void _claim(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
      throw ArgumentError.value(
        path,
        'path',
        'not a module-relative posix path',
      );
    }
    if (path == '.mcgen' || path.startsWith('.mcgen/')) {
      throw ArgumentError.value(path, 'path', '.mcgen/ belongs to the writer');
    }
    if (_libraries.containsKey(path) ||
        _files.containsKey(path) ||
        _deferred.containsKey(path)) {
      throw StateError('$path is emitted twice');
    }
  }

  /// Resolves imports, renders every library, then the deferred files.
  /// Throws [SymbolError] for unknown or ambiguous references.
  (List<EmittedFile>, UseGraph) finish() {
    final resolved = [
      for (final path in (_libraries.keys.toList()..sort()))
        resolveLibrary(
          _libraries[path]!,
          symbols,
          selfUri: _libraries[path]!.uriIn(package),
        ),
    ];
    final graph = UseGraph(package, resolved);
    final out = <EmittedFile>[
      for (final r in resolved)
        EmittedFile(
          r.library.path,
          renderLibrary(r),
          owned: _ownedLibraries.contains(r.library.path),
        ),
      ..._files.values,
      for (final e in _deferred.entries)
        EmittedFile(e.key, e.value.$1(graph), owned: e.value.$2),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return (out, graph);
  }
}
