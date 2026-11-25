import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The layer a package lives in, from its top-level folder (plan 01 §1).
enum Layer { utility, feature, app }

/// One architecture violation.
class Violation {
  const Violation(this.rule, this.location, this.message);

  /// Short rule id: `layer`, `barrel-only`, `R4` or `R15`.
  final String rule;

  /// Workspace-relative file the violation was found in.
  final String location;
  final String message;

  @override
  String toString() => '[$rule] $location: $message';
}

class _Package {
  _Package(this.name, this.layer, this.dir, this.dependencies);

  final String name;
  final Layer layer;

  /// Absolute, normalised.
  final String dir;
  final Set<String> dependencies;
}

/// Checks the packages under [root] (the folders `utility/`, `feature/` and
/// `app/`) and returns every violation, sorted for stable output.
///
/// Rules (plan 01 §2 rows 2 and 4, §4.2, D-05, D-31):
/// - utility depends on utilities only; feature on utilities only (never
///   another feature); app on anything (`layer`);
/// - a package never imports another package's `src/`, and no relative path
///   leaves its own package (`barrel-only`);
/// - `package:x/testing.dart` is imported from `test/` only (`test-only`);
/// - a feature barrel exports with `show` and never a page, bloc or DI
///   initializer (`R4`);
/// - a route library imports no feature barrel, and every `RouteTargets`
///   member returns a `*Flow` (`R15`).
///
/// Directives are read with `package:analyzer`'s parser, so every URI of a
/// directive is checked, including conditional (`if (...)`) alternatives.
List<Violation> checkArchitecture(String root) {
  final absRoot = p.normalize(p.absolute(root));
  final packages = _discoverPackages(absRoot);
  final byName = <String, _Package>{for (final pkg in packages) pkg.name: pkg};
  final violations = <Violation>[];
  for (final pkg in packages) {
    violations.addAll(_checkPubspec(absRoot, pkg, byName));
    for (final file in _dartFiles(pkg.dir)) {
      final unit = parseString(
        content: file.readAsStringSync(),
        path: file.path,
        throwIfDiagnostics: false,
      ).unit;
      final ctx = _FileContext(absRoot, file.path, pkg, packages, byName, unit);
      violations.addAll(_checkImports(ctx));
      if (pkg.layer == Layer.app) {
        violations.addAll(_checkRoutes(ctx));
      }
    }
    if (pkg.layer == Layer.feature) {
      violations.addAll(_checkBarrel(absRoot, pkg));
    }
  }
  violations.sort((a, b) => a.toString().compareTo(b.toString()));
  return violations;
}

class _FileContext {
  _FileContext(
    this.root,
    this.path,
    this.pkg,
    this.packages,
    this.byName,
    this.unit,
  );

  final String root;
  final String path;
  final _Package pkg;
  final List<_Package> packages;
  final Map<String, _Package> byName;
  final CompilationUnit unit;

  String get rel => p.relative(path, from: root);
}

List<_Package> _discoverPackages(String root) {
  final packages = <_Package>[];
  for (final layer in Layer.values) {
    final top = Directory(p.join(root, layer.name));
    if (!top.existsSync()) {
      continue;
    }
    for (final entity in top.listSync(recursive: true, followLinks: true)) {
      if (p.basename(entity.path) != 'pubspec.yaml' ||
          !FileSystemEntity.isFileSync(entity.path)) {
        continue;
      }
      final rel = p.relative(entity.path, from: root);
      if (_isIgnored(p.split(rel))) {
        continue;
      }
      final yaml = loadYaml(File(entity.path).readAsStringSync());
      if (yaml is! YamlMap || yaml['name'] is! String) {
        continue;
      }
      packages.add(
        _Package(
          yaml['name'] as String,
          layer,
          p.normalize(p.dirname(entity.path)),
          {..._keys(yaml['dependencies']), ..._keys(yaml['dev_dependencies'])},
        ),
      );
    }
  }
  return packages;
}

Set<String> _keys(Object? section) =>
    section is YamlMap ? section.keys.cast<String>().toSet() : <String>{};

/// Test fixtures hold deliberately broken packages, and build output holds
/// copies of the sources.
bool _isIgnored(List<String> segments) => segments.any(
  (s) =>
      s == 'fixtures' ||
      s == 'build' ||
      s.startsWith('.') ||
      s.startsWith('bazel-'),
);

Iterable<File> _dartFiles(String packageDir) sync* {
  for (final sub in const ['lib', 'test', 'bin']) {
    final dir = Directory(p.join(packageDir, sub));
    if (!dir.existsSync()) {
      continue;
    }
    for (final entity in dir.listSync(recursive: true, followLinks: true)) {
      if (entity.path.endsWith('.dart') &&
          FileSystemEntity.isFileSync(entity.path)) {
        yield File(entity.path);
      }
    }
  }
}

String? _layerViolation(Layer from, Layer to) {
  if (from == Layer.app) {
    return null;
  }
  if (from == Layer.utility && to != Layer.utility) {
    return '${from.name} → ${to.name}: a utility depends on utilities only';
  }
  if (from == Layer.feature && to == Layer.feature) {
    return 'feature → feature: no feature knows another feature';
  }
  if (from == Layer.feature && to == Layer.app) {
    return 'feature → app: a feature depends on utilities only';
  }
  return null;
}

Iterable<Violation> _checkPubspec(
  String root,
  _Package pkg,
  Map<String, _Package> byName,
) sync* {
  final location = p.relative(p.join(pkg.dir, 'pubspec.yaml'), from: root);
  for (final dep in pkg.dependencies) {
    final target = byName[dep];
    if (target == null || target == pkg) {
      continue;
    }
    final problem = _layerViolation(pkg.layer, target.layer);
    if (problem != null) {
      yield Violation(
        'layer',
        location,
        '${pkg.name} depends on $dep, $problem',
      );
    }
  }
}

/// Every URI a directive can resolve to: the main one and each conditional
/// alternative (`if (dart.library.io) 'package:x/x_io.dart'`).
Iterable<String> _uris(NamespaceDirective directive) sync* {
  final main = directive.uri.stringValue;
  if (main != null) {
    yield main;
  }
  for (final configuration in directive.configurations) {
    final alternative = configuration.uri.stringValue;
    if (alternative != null) {
      yield alternative;
    }
  }
}

/// The package a file path belongs to, or null.
_Package? _owner(String path, List<_Package> packages) {
  _Package? best;
  for (final pkg in packages) {
    if (p.isWithin(pkg.dir, path) &&
        (best == null || pkg.dir.length > best.dir.length)) {
      best = pkg;
    }
  }
  return best;
}

Iterable<Violation> _checkImports(_FileContext ctx) sync* {
  for (final directive in ctx.unit.directives.whereType<NamespaceDirective>()) {
    for (final uri in _uris(directive)) {
      yield* _checkUri(ctx, uri);
    }
  }
}

Iterable<Violation> _checkUri(_FileContext ctx, String uri) sync* {
  final pkg = ctx.pkg;
  if (uri.startsWith('package:')) {
    final slash = uri.indexOf('/');
    if (slash < 0) {
      return;
    }
    final name = uri.substring('package:'.length, slash);
    final path = uri.substring(slash + 1);
    final target = ctx.byName[name];
    if (target == null || target == pkg) {
      return;
    }
    yield* _edge(ctx, target, 'package:$name');
    if (path == 'testing.dart' &&
        !p.isWithin(p.join(pkg.dir, 'test'), ctx.path)) {
      yield Violation(
        'test-only',
        ctx.rel,
        'imports package:$name/testing.dart outside test/; test hooks are '
            'for tests only',
      );
    }
    if (path.startsWith('src/')) {
      yield Violation(
        'barrel-only',
        ctx.rel,
        'imports package:$name/$path; import the barrel '
            'package:$name/$name.dart (barrel-only, no package:x/src/)',
      );
    }
    return;
  }
  if (uri.contains(':')) {
    return; // dart:, file: and so on
  }
  // A relative URI: resolve it and see where it lands.
  final resolved = p.normalize(p.join(p.dirname(ctx.path), uri));
  if (p.isWithin(pkg.dir, resolved)) {
    return;
  }
  final target = _owner(resolved, ctx.packages);
  if (target != null) {
    yield* _edge(ctx, target, 'a relative path into ${target.name}');
  }
  yield Violation(
    'barrel-only',
    ctx.rel,
    'relative import $uri leaves package ${pkg.name} (barrel-only: reach '
        'other packages through package:<name>/<name>.dart)',
  );
}

Iterable<Violation> _edge(_FileContext ctx, _Package target, String how) sync* {
  final problem = _layerViolation(ctx.pkg.layer, target.layer);
  if (problem != null) {
    yield Violation('layer', ctx.rel, '${ctx.pkg.name} imports $how, $problem');
  }
}

final RegExp _forbiddenSymbol = RegExp(
  r'(Page|Bloc|DIInitializer|DiInitializer)$',
);

/// Resolves an export URI of [pkg]'s barrel to a file, or null when it points
/// outside the package.
String? _exportFile(_Package pkg, String uri) {
  if (uri.startsWith('package:${pkg.name}/')) {
    return p.join(pkg.dir, 'lib', uri.substring('package:${pkg.name}/'.length));
  }
  if (!uri.contains(':')) {
    return p.normalize(p.join(pkg.dir, 'lib', uri));
  }
  return null;
}

/// Names of the classes, mixins and extension types a file declares.
Iterable<String> _declaredTypes(String path) sync* {
  final file = File(path);
  if (!file.existsSync()) {
    return;
  }
  final unit = parseString(
    content: file.readAsStringSync(),
    path: path,
    throwIfDiagnostics: false,
  ).unit;
  for (final declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      yield declaration.namePart.typeName.lexeme;
    }
  }
}

/// R4: a feature barrel exports flows, navigators and arg/result types, never
/// a page, a bloc or a DI initializer. Every export names its symbols with
/// `show` (plan 01 D-05); a wildcard export is itself a violation, and the
/// forbidden symbols the file declares are named.
Iterable<Violation> _checkBarrel(String root, _Package pkg) sync* {
  final barrel = File(p.join(pkg.dir, 'lib', '${pkg.name}.dart'));
  if (!barrel.existsSync()) {
    return;
  }
  final rel = p.relative(barrel.path, from: root);
  final unit = parseString(
    content: barrel.readAsStringSync(),
    path: barrel.path,
    throwIfDiagnostics: false,
  ).unit;
  for (final directive in unit.directives.whereType<ExportDirective>()) {
    for (final uri in _uris(directive)) {
      final shown = <String>[
        for (final c in directive.combinators.whereType<ShowCombinator>())
          for (final name in c.shownNames) name.name,
      ];
      var flagged = false;
      for (final symbol in shown) {
        if (_forbiddenSymbol.hasMatch(symbol)) {
          flagged = true;
          yield Violation(
            'R4',
            rel,
            'barrel exports $symbol (from $uri); a feature barrel exports '
                'only flows, navigators and arg/result types',
          );
        }
      }
      if (shown.isNotEmpty || flagged) {
        continue;
      }
      final file = _exportFile(pkg, uri);
      final declared = file == null
          ? const <String>[]
          : _declaredTypes(file).where(_forbiddenSymbol.hasMatch).toList();
      yield Violation(
        'R4',
        rel,
        'barrel exports all of $uri without show'
            '${declared.isEmpty ? '' : ', including ${declared.join(', ')}'}; '
            'a feature barrel lists the flows, navigators and arg/result types '
            'it exports with show',
      );
    }
  }
}

const _routeAnnotations = {
  'TypedGoRoute',
  'TypedShellRoute',
  'TypedStatefulShellRoute',
};

/// R15: a route library (one with typed-route annotations) imports no feature
/// barrel, so its codegen closure stays free of Flutter feature code. Route
/// targets are reached through `RouteTargets`, whose members return `*Flow`.
Iterable<Violation> _checkRoutes(_FileContext ctx) sync* {
  final isRouteLibrary = ctx.unit.declarations.any(
    (d) => d.metadata.any((m) => _routeAnnotations.contains(m.name.name)),
  );
  if (isRouteLibrary) {
    for (final directive in ctx.unit.directives.whereType<ImportDirective>()) {
      for (final uri in _uris(directive)) {
        if (!uri.startsWith('package:')) {
          continue;
        }
        final name = uri.substring('package:'.length, uri.indexOf('/'));
        final target = ctx.byName[name];
        if (target != null && target.layer == Layer.feature) {
          yield Violation(
            'R15',
            ctx.rel,
            'route library imports feature barrel package:$name; '
                'use RouteTargets (route_targets.dart) instead',
          );
        }
      }
    }
  }
  if (p.basename(ctx.path) == 'route_targets.dart') {
    yield* _checkRouteTargets(ctx);
  }
}

Iterable<Violation> _checkRouteTargets(_FileContext ctx) sync* {
  for (final declaration in ctx.unit.declarations) {
    if (declaration is! ClassDeclaration ||
        declaration.namePart.typeName.lexeme != 'RouteTargets') {
      continue;
    }
    for (final member
        in declaration.body.members.whereType<MethodDeclaration>()) {
      if (member.isStatic || member.isOperator || member.isSetter) {
        continue;
      }
      final type = member.returnType?.toSource() ?? 'dynamic';
      final bare = type.endsWith('?')
          ? type.substring(0, type.length - 1)
          : type;
      if (!bare.endsWith('Flow')) {
        yield Violation(
          'R15',
          ctx.rel,
          'RouteTargets.${member.name.lexeme} returns $type; a route builds a '
              '*Flow, never a page or another widget',
        );
      }
    }
  }
}
