// The BUILD.bazel of a wiring group `mcgen wire` generates (T-0074): the
// shape of the hand-written groups' (universe_wiring, T-0033). The typed
// routes go through go_router_builder over `_stage` (the route targets, R15),
// the navigator implementations through injectable, and every dep list is
// what the files import.

import 'package:mcgen/src/buildgen/dart_scan.dart';
import 'package:mcgen/src/buildgen/merge.dart';
import 'package:mcgen/src/buildgen/starlark.dart';
import 'package:path/path.dart' as p;

class WiringPackage {
  WiringPackage._(this.name, this.dir, this.lib, this.test);

  factory WiringPackage.read(String name, String dir) =>
      WiringPackage._(name, dir, dartFiles(dir, 'lib'), dartFiles(dir, 'test'));

  final String name;
  final String dir;
  final List<DartFile> lib;
  final List<DartFile> test;

  /// The route libraries (a go_router_builder `.g.dart` part), by group name.
  List<(String, String)> get routes => [
    for (final f in lib)
      if (f.path.startsWith('lib/src/routes/') &&
          f.path.endsWith('_routes.dart') &&
          f.hasG)
        (
          p.posix
              .basenameWithoutExtension(f.path)
              .replaceFirst(RegExp(r'_routes$'), ''),
          f.path,
        ),
  ];

  List<String> get navigators => [
    for (final f in lib)
      if (f.path.startsWith('lib/src/navigators/')) f.path,
  ];

  List<String> get tests => [
    for (final f in test)
      if (RegExp(r'^test/[^/]+_test\.dart$').hasMatch(f.path))
        p.posix.basenameWithoutExtension(f.path),
  ];
}

/// [pkg]'s canonical BUILD file, merged with [existing] (ADR-0018).
String wiringBuild(
  WiringPackage pkg,
  BuildFile? existing, {
  required String Function(String package) label,
  required String header,
}) {
  final w = BuildWriter(existing);
  final name = pkg.name;
  List<String> labels(Iterable<String> packages) => [
    for (final x in packages.toSet())
      if (x != name) label(x),
  ]..sort(compareLabels);

  w.add(
    'load:@rules_dart//dart:defs.bzl',
    'load("@rules_dart//dart:defs.bzl", "dart_codegen")\n',
    lead: header,
  );
  w.add(
    'load:@rules_dart//dart/ext/injectable:defs.bzl',
    'load("@rules_dart//dart/ext/injectable:defs.bzl", "injectable_package")\n',
    lead: '',
  );
  w.add(
    'load:@rules_flutter//flutter:defs.bzl',
    'load("@rules_flutter//flutter:defs.bzl", "flutter_library", "flutter_test")\n',
    lead: '',
  );
  w.add(
    'load://tool/bazel:defs.bzl',
    'load("//tool/bazel:defs.bzl", "MC_GENERATED_DART")\n',
    lead: '',
  );
  w.add(
    'package',
    'package(default_visibility = ["//app:__subpackages__"])\n',
  );
  w.add('var:_PKG', '_PKG = "$name"\n');
  w.add('var:_LANG', '_LANG = "3.13"  # the pubspec floor (F-0011)\n');
  final routes = pkg.routes;
  w.add(
    'var:_ROUTES',
    '_ROUTES = {\n'
        '${[for (final (n, s) in routes) '    "$n": "$s",\n'].join()}'
        '}\n',
  );
  w.add('var:_INIT', '_INIT = "lib/src/di/di_initializer.dart"\n');
  w.add('var:_NAVIGATORS', w.listVar('_NAVIGATORS', pkg.navigators));
  final deps = w.kept('var:_DEPS', '_DEPS', {
    ...labels({for (final f in pkg.lib) ...f.packages}),
  });
  w.add('var:_DEPS', w.listVar('_DEPS', deps, keptOf: 'var:_DEPS'));
  w.add(
    'rule:_stage',
    'flutter_library(\n'
        '    name = "_stage",\n'
        '    package_name = _PKG,\n'
        '    srcs = ["lib/src/routes/route_targets.dart"],\n'
        '    language_version = _LANG,\n'
        '    tags = [\n'
        '        "no-dart-analyze",\n'
        '        "no-dart-format",\n'
        '    ],\n'
        '    deps = _DEPS,\n'
        ')\n',
    lead: '\n# Generator input only: the files the generators resolve imports through.\n',
  );
  w.add(
    'rule:_%s_routes_go_router_part',
    '[dart_codegen(\n'
        '    name = "_%s_routes_go_router_part" % name,\n'
        '    package_name = _PKG,\n'
        '    src = src,\n'
        '    generator_bin = "@rules_dart//dart/ext/go_router:shim",\n'
        '    language_version = _LANG,\n'
        '    output_suffixes = [".go_router.g.part"],\n'
        '    deps = [\n'
        '        ":_stage",\n'
        '        "@flutter_sky_engine//:sky_engine",\n'
        '    ] + _DEPS,\n'
        ') for name, src in _ROUTES.items()]\n',
    lead: '\n# --- go_router_builder (F-0007 workaround: sky_engine turns summaries off) ---\n',
  );
  w.add(
    'rule:_%s_routes_g',
    '[dart_codegen(\n'
        '    name = "_%s_routes_g" % name,\n'
        '    package_name = _PKG,\n'
        '    src = src,\n'
        '    generator_bin = "@rules_dart//dart/ext/_shared/combining_shim:bin",\n'
        '    language_version = _LANG,\n'
        '    output_suffixes = [".g.dart"],\n'
        '    parts = [":_%s_routes_go_router_part" % name],\n'
        ') for name, src in _ROUTES.items()]\n',
  );
  w.add(
    'rule:di_config',
    'injectable_package(\n'
        '    name = "di_config",\n'
        '    srcs = _NAVIGATORS,\n'
        '    init = _INIT,\n'
        '    init_deps = ["//utility/mc_di"],\n'
        '    language_version = _LANG,\n'
        '    package_name = _PKG,\n'
        '    shard_deps = [\n'
        '        ":_stage",\n'
        '        "@flutter_sky_engine//:sky_engine",\n'
        '    ] + _DEPS,\n'
        ')\n',
    lead: '\n# --- injectable (fork patch 0002) ${'-' * 43}\n',
  );
  w.add(
    'var:_CODEGEN',
    w.listVar('_CODEGEN', [
      for (final (n, _) in routes) ':_${n}_routes_g',
      ':di_config',
    ]),
  );
  w.add(
    'rule:$name',
    'flutter_library(\n'
        '    name = "$name",\n'
        '    package_name = _PKG,\n'
        '    srcs = glob(\n'
        '        ["lib/**/*.dart"],\n'
        '        exclude = MC_GENERATED_DART,\n'
        '    ) + _CODEGEN,\n'
        '    language_version = _LANG,\n'
        '    deps = _DEPS,\n'
        ')\n',
  );
  final tests = pkg.tests;
  if (tests.isNotEmpty) {
    final testDeps = w.kept(
      'var:_TEST_DEPS',
      '_TEST_DEPS',
      {
        ':$name',
        ...labels({for (final f in pkg.test) ...f.packages}),
      },
      minus: deps.toSet(),
    );
    w.add(
      'var:_TEST_DEPS',
      w
          .listVar('_TEST_DEPS', testDeps, keptOf: 'var:_TEST_DEPS')
          .replaceFirst('_TEST_DEPS = [', '_TEST_DEPS = _DEPS + ['),
    );
    // A comprehension named by its loop variable has no string name.
    w.add(
      'expr:[ flutter_test ( name',
      '[flutter_test(\n'
          '    name = t,\n'
          '    size = "small",\n'
          '    package_name = _PKG,\n'
          '    language_version = _LANG,\n'
          '    main = "test/%s.dart" % t,\n'
          '    deps = _TEST_DEPS,\n'
          ') for t in [\n'
          '${[for (final t in tests) '    "$t",\n'].join()}'
          ']]\n',
    );
  }
  return w.finish();
}
