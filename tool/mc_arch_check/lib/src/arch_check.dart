import 'dart:io';

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
  final String dir;
  final Set<String> dependencies;
}

final RegExp _directive = RegExp(
  r'''^\s*(import|export)\s+['"]package:([a-z0-9_]+)/([^'"]+)['"]([^;]*);''',
  multiLine: true,
);

/// Checks the packages under [root] (the folders `utility/`, `feature/` and
/// `app/`) and returns every violation, sorted for stable output.
///
/// Rules (plan 01 §2 rows 2 and 4, §4.2, D-05, D-31):
/// - utility depends on utilities only; feature on utilities only (never
///   another feature); app on anything (`layer`);
/// - a package never imports another package's `src/` (`barrel-only`);
/// - a feature barrel exports no page, bloc or DI initializer (`R4`);
/// - a route library imports no feature barrel, and `RouteTargets` methods
///   return a `*Flow` (`R15`).
List<Violation> checkArchitecture(String root) {
  final packages = _discoverPackages(root);
  final byName = <String, _Package>{for (final pkg in packages) pkg.name: pkg};
  final violations = <Violation>[];
  for (final pkg in packages) {
    violations.addAll(_checkPubspec(root, pkg, byName));
    for (final file in _dartFiles(pkg.dir)) {
      final rel = p.relative(file.path, from: root);
      final source = file.readAsStringSync();
      violations.addAll(_checkImports(rel, source, pkg, byName));
      if (pkg.layer == Layer.app) {
        violations.addAll(_checkRoutes(rel, source, byName));
      }
    }
    if (pkg.layer == Layer.feature) {
      violations.addAll(_checkBarrel(root, pkg));
    }
  }
  violations.sort((a, b) => a.toString().compareTo(b.toString()));
  return violations;
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
        _Package(yaml['name'] as String, layer, p.dirname(entity.path), {
          ..._keys(yaml['dependencies']),
          ..._keys(yaml['dev_dependencies']),
        }),
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

Iterable<Violation> _checkImports(
  String rel,
  String source,
  _Package pkg,
  Map<String, _Package> byName,
) sync* {
  for (final match in _directive.allMatches(source)) {
    final name = match.group(2)!;
    final path = match.group(3)!;
    final target = byName[name];
    if (target == null || target == pkg) {
      continue;
    }
    final problem = _layerViolation(pkg.layer, target.layer);
    if (problem != null) {
      yield Violation(
        'layer',
        rel,
        '${pkg.name} imports package:$name, $problem',
      );
    }
    if (path.startsWith('src/')) {
      yield Violation(
        'barrel-only',
        rel,
        'imports package:$name/$path; import the barrel package:$name/$name.dart '
            '(barrel-only, no package:x/src/)',
      );
    }
  }
}

final RegExp _forbiddenSymbol = RegExp(
  r'(Page|Bloc|DIInitializer|DiInitializer)$',
);
final RegExp _forbiddenFile = RegExp(r'(_page|_bloc|di_initializer)\.dart$');

/// R4: a feature barrel exports flows, navigators and argument/result types,
/// never a page, a bloc or a DI initializer.
Iterable<Violation> _checkBarrel(String root, _Package pkg) sync* {
  final barrel = File(p.join(pkg.dir, 'lib', '${pkg.name}.dart'));
  if (!barrel.existsSync()) {
    return;
  }
  final rel = p.relative(barrel.path, from: root);
  for (final match in _directive.allMatches(barrel.readAsStringSync())) {
    if (match.group(1) != 'export') {
      continue;
    }
    final file = match.group(3)!;
    final shown = RegExp(r'\bshow\b([^;]*)').firstMatch(match.group(4)!);
    if (shown != null) {
      final symbols = shown
          .group(1)!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final symbol in symbols) {
        if (_forbiddenSymbol.hasMatch(symbol)) {
          yield Violation(
            'R4',
            rel,
            'barrel exports $symbol (from $file); a feature barrel exports '
                'only flows, navigators and arg/result types',
          );
        }
      }
    } else if (_forbiddenFile.hasMatch(file)) {
      yield Violation(
        'R4',
        rel,
        'barrel exports all of $file (a page, bloc or DI initializer); a '
            'feature barrel exports only flows, navigators and arg/result types',
      );
    }
  }
}

final RegExp _routeAnnotation = RegExp(
  r'@(TypedGoRoute|TypedShellRoute|TypedStatefulShellRoute)\b',
);

/// R15: a route library (one with typed-route annotations) imports no feature
/// barrel, so its codegen closure stays free of Flutter feature code. Route
/// targets are reached through `RouteTargets`, whose methods return `*Flow`.
Iterable<Violation> _checkRoutes(
  String rel,
  String source,
  Map<String, _Package> byName,
) sync* {
  if (_routeAnnotation.hasMatch(source)) {
    for (final match in _directive.allMatches(source)) {
      if (match.group(1) != 'import') {
        continue;
      }
      final target = byName[match.group(2)!];
      if (target != null && target.layer == Layer.feature) {
        yield Violation(
          'R15',
          rel,
          'route library imports feature barrel package:${target.name}; '
              'use RouteTargets (route_targets.dart) instead',
        );
      }
    }
  }
  if (p.basename(rel) == 'route_targets.dart') {
    yield* _checkRouteTargets(rel, source);
  }
}

final RegExp _routeTargetMethod = RegExp(
  r'^\s*(?:abstract\s+)?([A-Za-z_][\w<>?, ]*?)\s+([a-z]\w*)\s*\(',
  multiLine: true,
);

Iterable<Violation> _checkRouteTargets(String rel, String source) sync* {
  final start = source.indexOf(RegExp(r'class\s+RouteTargets\b'));
  if (start < 0) {
    return;
  }
  final body = source.substring(start);
  for (final match in _routeTargetMethod.allMatches(body)) {
    final type = match.group(1)!.trim();
    final name = match.group(2)!;
    if (const {'return', 'if', 'for', 'while', 'switch', 'of'}.contains(name) ||
        type.startsWith('static') ||
        type.contains('class ')) {
      continue;
    }
    if (!type.endsWith('Flow')) {
      yield Violation(
        'R15',
        rel,
        'RouteTargets.$name returns $type; a route builds a *Flow, never a '
            'page or another widget',
      );
    }
  }
}
