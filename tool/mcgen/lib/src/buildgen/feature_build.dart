// The canonical BUILD.bazel of a feature package (T-0074, ADR-0018): every
// statement follows from the package's files. Generators read only
// Flutter-free libraries (R15), so the hand-written pure files form `_stage`;
// a json DTO and the retrofit API get the narrow `_stage_dto` lane (F-0031
// fact 4); every dep list is the packages the files of that target import,
// plus the runtimes generated code uses without an import in the source.

import 'dart:io';

import 'package:mcgen/src/buildgen/dart_scan.dart';
import 'package:mcgen/src/buildgen/merge.dart';
import 'package:mcgen/src/buildgen/starlark.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The pure (Flutter-free) source globs a feature may have, in BUILD order.
/// Each is used when the package has a file it matches.
const _pureCandidates = [
  'lib/src/di/di_module.dart',
  'lib/src/di/flow_scope.dart',
  'lib/src/domain/**/*.dart',
  'lib/src/flags/**/*.dart',
  // lib/src/flow/<x>_flow_state.dart goes here (one file, by name).
  'lib/src/navigator/**/*.dart',
  'lib/src/presentation/bloc/**/*.dart',
  'lib/src/presentation/form/**/*.dart',
];

/// What a test target of the bdd/flow-scope family gets without importing it
/// in the step files: the BDD macro adds them itself.
const _bddOwn = {'flutter', 'flutter_test', 'mc_test_steps', 'mc_test_utils'};

bool _matches(String glob, String path) {
  if (glob.endsWith('/**/*.dart')) {
    return path.startsWith(
          glob.substring(0, glob.length - '**/*.dart'.length),
        ) &&
        path.endsWith('.dart');
  }
  return glob == path;
}

/// One test target besides the BDD suite.
class _Test {
  _Test(this.name, this.file, {required this.shared, required this.dart});

  final String name;
  final DartFile file;

  /// Builds over the test env (`test/feature/util/*.dart`) and `_TEST_DEPS`.
  final bool shared;

  /// A pure-Dart test (`package:test`), not a Flutter one.
  final bool dart;
}

/// What buildgen reads from a feature package.
class FeaturePackage {
  FeaturePackage._(this.name, this.dir, this.files, this.l10n);

  /// Reads the package at [dir] (absolute), named [name].
  factory FeaturePackage.read(String name, String dir) {
    final files = [...dartFiles(dir, 'lib'), ...dartFiles(dir, 'test')];
    final l10nFile = File(p.join(dir, 'l10n.yaml'));
    final arbs = Directory(p.join(dir, 'lib/src/l10n'));
    Map<String, String>? l10n;
    if (l10nFile.existsSync() &&
        arbs.existsSync() &&
        arbs.listSync().any((e) => e.path.endsWith('.arb'))) {
      final y = loadYaml(l10nFile.readAsStringSync()) as YamlMap;
      l10n = {for (final e in y.entries) '${e.key}': '${e.value}'};
    }
    return FeaturePackage._(name, dir, files, l10n);
  }

  final String name;
  final String dir;
  final List<DartFile> files;

  /// l10n.yaml's settings, when the package has ARBs.
  final Map<String, String>? l10n;

  Iterable<DartFile> get lib => files.where((f) => f.path.startsWith('lib/'));
  Iterable<DartFile> get test => files.where((f) => f.path.startsWith('test/'));

  DartFile? file(String path) {
    for (final f in files) {
      if (f.path == path) return f;
    }
    return null;
  }

  late final String? flowState = () {
    for (final f in lib) {
      if (RegExp(r'^lib/src/flow/[^/]+_flow_state\.dart$').hasMatch(f.path)) {
        return f.path;
      }
    }
    return null;
  }();

  late final List<String> pureGlobs = () {
    final out = <String>[];
    for (final g in _pureCandidates) {
      if (g == 'lib/src/navigator/**/*.dart' && flowState != null) {
        out.add(flowState!);
      }
      if (lib.any((f) => _matches(g, f.path))) out.add(g);
    }
    return out;
  }();

  late final List<DartFile> pure = [
    for (final f in lib)
      if (pureGlobs.any((g) => _matches(g, f.path))) f,
  ];

  late final List<DartFile> freezed = [
    for (final f in lib)
      if (f.hasFreezed) f,
  ];

  /// The json DTO file: a model with a `.g.dart` part.
  late final DartFile? dto = () {
    final dtos = [
      for (final f in lib)
        if (f.hasG && !f.isRetrofit) f,
    ];
    if (dtos.length > 1) {
      throw StateError(
        '$name: buildgen supports one json DTO file per feature, found '
        '${dtos.map((f) => f.path).join(', ')}',
      );
    }
    return dtos.isEmpty ? null : dtos.single;
  }();

  late final DartFile? api = () {
    final apis = [
      for (final f in lib)
        if (f.isRetrofit) f,
    ];
    if (apis.length > 1) {
      throw StateError('$name: buildgen supports one retrofit API per feature');
    }
    return apis.isEmpty ? null : apis.single;
  }();

  late final List<String> injectable = [
    for (final f in lib)
      if (f.isInjectable) f.path,
  ];

  bool get hasDi => file('lib/src/di/di_initializer.dart') != null;

  List<String> get features {
    final d = Directory(p.join(dir, 'test/feature'));
    if (!d.existsSync()) return const [];
    return [
      for (final e in d.listSync())
        if (e is File && e.path.endsWith('.feature')) p.basename(e.path),
    ]..sort();
  }

  late final List<DartFile> util = [
    for (final f in test)
      if (RegExp(r'^test/feature/util/[^/]+\.dart$').hasMatch(f.path)) f,
  ];

  late final List<DartFile> steps = [
    for (final f in test)
      if (f.path.startsWith('test/feature/step/')) f,
  ];

  /// The env BDD runs once (`void bddSetUpAll()`), if any.
  String? get env {
    for (final f in util) {
      if (f.path == 'test/feature/util/${name}_env.dart' ||
          RegExp(r'\bvoid bddSetUpAll\(').hasMatch(f.text)) {
        return f.path;
      }
    }
    return null;
  }

  DartFile? get contract {
    final c = [
      for (final f in test)
        if (RegExp(r'^test/contract/[^/]+_contract_test\.dart$')
            .hasMatch(f.path))
          f,
    ];
    return c.length == 1 ? c.single : null;
  }

  DartFile? get golden {
    final g = [
      for (final f in test)
        if (RegExp(r'^test/golden/[^/]+_golden_test\.dart$').hasMatch(f.path))
          f,
    ];
    return g.length == 1 ? g.single : null;
  }
}

/// Writes [pkg]'s canonical BUILD file, merged with [existing] (ADR-0018).
/// [label] maps a package name to its Bazel label.
String featureBuild(
  FeaturePackage pkg,
  BuildFile? existing, {
  required String Function(String package) label,
  required String header,
}) {
  final w = BuildWriter(existing);
  final name = pkg.name;
  List<String> labels(Iterable<String> packages) => [
    for (final x in packages.toSet())
      if (x != name) label(x),
  ];
  Set<String> packagesOf(Iterable<DartFile> files) => {
    for (final f in files) ...f.packages,
  };

  // --- loads, package, constants ---------------------------------------------
  final usesCodegen =
      pkg.freezed.isNotEmpty || pkg.dto != null || pkg.api != null;
  final dartSyms = [
    if (usesCodegen) 'dart_codegen',
    'dart_library',
    'dart_test',
  ];
  w.add(
    'load:@rules_dart//dart:defs.bzl',
    'load("@rules_dart//dart:defs.bzl", ${dartSyms.map((s) => '"$s"').join(', ')})\n',
    lead: header,
  );
  if (pkg.hasDi) {
    w.add(
      'load:@rules_dart//dart/ext/injectable:defs.bzl',
      'load("@rules_dart//dart/ext/injectable:defs.bzl", "injectable_package")\n',
      lead: '',
    );
  }
  final flutterSyms = [
    if (pkg.l10n != null) 'flutter_gen_l10n',
    'flutter_library',
    'flutter_test',
  ];
  w.add(
    'load:@rules_flutter//flutter:defs.bzl',
    'load("@rules_flutter//flutter:defs.bzl", ${flutterSyms.map((s) => '"$s"').join(', ')})\n',
    lead: '',
  );
  final features = pkg.features;
  w.add(
    'load://tool/bazel:defs.bzl',
    'load("//tool/bazel:defs.bzl", "MC_GENERATED_DART"${features.isEmpty ? '' : ', "mc_bdd_tests"'})\n',
    lead: '',
  );
  w.add(
    'package',
    'package(default_visibility = ["//visibility:private"])\n',
  );
  w.add('var:_PKG', '_PKG = "$name"\n');
  w.add(
    'var:_LANG',
    '_LANG = "3.13"  # the pubspec floor; codegen equals build_runner only with it (F-0011)\n',
  );
  if (pkg.hasDi)
    w.add('var:_INIT', '_INIT = "lib/src/di/di_initializer.dart"\n');

  // --- the generator-read lane -----------------------------------------------
  final pureDeps = w.kept('var:_PURE_DEPS', '_PURE_DEPS', {
    ...labels(packagesOf(pkg.pure)),
    // injectable's output uses get_it; json_serializable's json_annotation.
    if (pkg.hasDi) label('get_it'),
    if (pkg.dto != null) label('json_annotation'),
  });
  w.add(
    'var:_PURE_DEPS',
    w.listVar('_PURE_DEPS', pureDeps, keptOf: 'var:_PURE_DEPS'),
    lead: '\n# Pure-Dart deps of the hand-written, generator-read files.\n',
  );
  w.add(
    'var:_PURE_SRCS',
    '_PURE_SRCS = glob(\n'
        '    [\n'
        '${[for (final g in pkg.pureGlobs) '        "$g",\n'].join()}'
        '    ],\n'
        '    exclude = MC_GENERATED_DART,\n'
        ')\n',
    lead:
        '\n# The Flutter-free hand-written files: domain, navigator, flow state, blocs and\n'
        '# the root-import list. Pages, widgets, the flow widget and l10n are Flutter.\n',
  );
  w.add(
    'rule:_stage',
    'dart_library(\n'
        '    name = "_stage",\n'
        '    package_name = _PKG,\n'
        '    srcs = _PURE_SRCS,\n'
        '    language_version = _LANG,\n'
        '    tags = [\n'
        '        "no-dart-analyze",\n'
        '        "no-dart-format",\n'
        '    ],\n'
        '    deps = _PURE_DEPS,\n'
        ')\n',
    lead: '\n# Generator input only (V3-18): never a dep of the package library or a test.\n',
  );

  // --- freezed, json, retrofit -----------------------------------------------
  // A freezed target keeps the name the BUILD file gave it; a new one is
  // named after its file.
  final oldNames = {
    for (final (k, v)
        in existing?['var:_FREEZED']?.stringPairs ?? const <(String, String)>[])
      v: k,
  };
  final freezed = <(String, String)>[
    for (final f in pkg.freezed)
      (oldNames[f.path] ?? p.posix.basenameWithoutExtension(f.path), f.path),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final dto = pkg.dto;
  final dtoFreezed = dto == null
      ? null
      : [
          for (final (n, s) in freezed)
            if (s == dto.path) n,
        ].firstOrNull;
  final dtoStem = dto == null
      ? null
      : p.posix.basenameWithoutExtension(dto.path);
  if (freezed.isNotEmpty) {
    w.add(
      'var:_FREEZED',
      '_FREEZED = {\n'
          '${[for (final (n, s) in freezed) '    "$n": "$s",\n'].join()}'
          '}\n',
      lead: '\n# --- freezed ${'-' * 64}\n',
    );
    final deps = dtoFreezed == null
        ? '    deps = [":_stage"],\n'
        : '    # The DTO imports only annotations, so its lane stays narrow.\n'
              '    deps = [\n'
              '        "@pub_deps//:freezed_annotation",\n'
              '        "@pub_deps//:json_annotation",\n'
              '    ] if name == "$dtoFreezed" else [":_stage"],\n';
    w.add(
      'rule:_%s_freezed',
      '[dart_codegen(\n'
          '    name = "_%s_freezed" % name,\n'
          '    package_name = _PKG,\n'
          '    src = src,\n'
          '    generator_bin = "@rules_dart//dart/ext/freezed:shim",\n'
          '    language_version = _LANG,\n'
          '    output_suffixes = [".freezed.dart"],\n'
          '$deps'
          ') for name, src in _FREEZED.items()]\n',
    );
  }
  if (dto != null) {
    if (dtoFreezed == null) {
      throw StateError('${pkg.name}: the json DTO ${dto.path} is not freezed');
    }
    w.add(
      'rule:_stage_dto',
      'dart_library(\n'
          '    name = "_stage_dto",\n'
          '    package_name = _PKG,\n'
          '    srcs = [\n'
          '        "${dto.path}",\n'
          '        ":_${dtoFreezed}_freezed",\n'
          '    ],\n'
          '    language_version = _LANG,\n'
          '    # The json part comes in the next stage, so this library doesn\'t analyze.\n'
          '    tags = [\n'
          '        "no-dart-analyze",\n'
          '        "no-dart-format",\n'
          '    ],\n'
          '    deps = [\n'
          '        "@pub_deps//:freezed_annotation",\n'
          '        "@pub_deps//:json_annotation",\n'
          '    ],\n'
          ')\n',
      lead: '\n${_rule('$dtoStem: json over the freezed output')}\n',
    );
    w.add(
      'rule:_${dtoStem}_json_part',
      'dart_codegen(\n'
          '    name = "_${dtoStem}_json_part",\n'
          '    package_name = _PKG,\n'
          '    src = "${dto.path}",\n'
          '    generator_bin = "@rules_dart//dart/ext/json_serializable:shim",\n'
          '    language_version = _LANG,\n'
          '    output_suffixes = [".json_serializable.g.part"],\n'
          '    deps = [":_stage_dto"],\n'
          ')\n',
    );
    w.add(
      'rule:_${dtoStem}_g',
      _combining('_${dtoStem}_g', '"${dto.path}"', '_${dtoStem}_json_part'),
    );
  }
  final api = pkg.api;
  final apiStem = api == null
      ? null
      : p.posix.basenameWithoutExtension(api.path);
  if (api != null) {
    final key = 'rule:_${apiStem}_retrofit_part';
    final deps = w.kept(key, 'deps', {
      if (dto != null) ':_stage_dto',
      ...labels(
        api.packages.difference({'freezed_annotation', 'json_annotation'}),
      ),
    });
    w.add(
      key,
      'dart_codegen(\n'
      '    name = "_${apiStem}_retrofit_part",\n'
      '    package_name = _PKG,\n'
      '    src = "${api.path}",\n'
      '    generator_bin = "@rules_dart//dart/ext/retrofit:shim",\n'
      '    language_version = _LANG,\n'
      '    output_suffixes = [".retrofit.g.part"],\n'
      '${w.listAttr('deps', deps, keptOf: key)}'
      ')\n',
      lead: '\n${_rule('$apiStem: retrofit (fork patch 0001)')}\n',
    );
    w.add(
      'rule:_${apiStem}_g',
      _combining('_${apiStem}_g', '"${api.path}"', '_${apiStem}_retrofit_part'),
    );
  }

  // --- injectable, l10n ------------------------------------------------------
  if (pkg.hasDi) {
    w.add(
      'rule:di_config',
      'injectable_package(\n'
          '    name = "di_config",\n'
          '${w.listAttr('srcs', pkg.injectable)}'
          '    init = _INIT,\n'
          '    init_deps = ["//utility/mc_di"],\n'
          '    language_version = _LANG,\n'
          '    package_name = _PKG,\n'
          '    shard_deps = [":_stage"],\n'
          ')\n',
      lead: '\n# --- injectable (fork patch 0002) ${'-' * 43}\n',
    );
  }
  final l10n = pkg.l10n;
  if (l10n != null) {
    String need(String k) =>
        l10n[k] ?? (throw StateError('${pkg.name}/l10n.yaml has no "$k"'));
    w.add(
      'rule:_l10n',
      'flutter_gen_l10n(\n'
          '    name = "_l10n",\n'
          '    arbs = glob(["lib/src/l10n/*.arb"]),\n'
          '    nullable_getter = ${l10n['nullable-getter'] == 'true' ? 'True' : 'False'},\n'
          '    output_class = "${need('output-class')}",\n'
          '    output_localization_file = "${need('output-localization-file')}",\n'
          '    template_arb_file = "${need('template-arb-file')}",\n'
          ')\n',
      lead:
          '\n# --- gen-l10n ${'-' * 63}\n'
          '# Outputs land beside the ARBs; the rule ignores l10n.yaml, so these attributes\n'
          '# mirror it (IDE / pub path: `flutter: generate: true`, F-0023).\n',
    );
    w.add(
      'rule:arbs',
      'filegroup(\n'
          '    name = "arbs",\n'
          '    srcs = glob(["lib/src/l10n/*.arb"]),\n'
          '    visibility = ["//tool/l10n_check:__pkg__"],\n'
          ')\n',
    );
  }
  final codegen =
      <(String, String)>[
        for (final (n, _) in freezed) (n, ':_${n}_freezed'),
        if (dto != null) (dtoStem!, ':_${dtoStem}_g'),
        if (api != null) (apiStem!, ':_${apiStem}_g'),
      ]..sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
  final codegenTargets = [
    for (final (_, t) in codegen) t,
    if (pkg.hasDi) ':di_config',
    if (l10n != null) ':_l10n',
  ];
  if (codegenTargets.isNotEmpty) {
    w.add('var:_CODEGEN', w.listVar('_CODEGEN', codegenTargets));
  }

  // --- the package library ---------------------------------------------------
  final pureSet = pureDeps.toSet();
  final flutterDeps = w.kept('var:_FLUTTER_DEPS', '_FLUTTER_DEPS', {
    ...labels(packagesOf(pkg.lib)).where((l) => !pureSet.contains(l)),
    // gen-l10n's output uses these without the sources naming them.
    if (l10n != null) ...[label('flutter_localizations'), label('intl')],
  });
  w.add(
    'var:_FLUTTER_DEPS',
    w.listVar('_FLUTTER_DEPS', flutterDeps, keptOf: 'var:_FLUTTER_DEPS'),
    lead: '\n# --- the package library ${'-' * 52}\n',
  );
  w.add(
    'rule:$name',
    'flutter_library(\n'
        '    name = "$name",\n'
        '    srcs = glob(\n'
        '        ["lib/**/*.dart"],\n'
        '        # `tool/ide_sync` and `fvm flutter pub get` write the generated files\n'
        '        # beside their sources for the IDE; Bazel builds its own copies.\n'
        '        exclude = MC_GENERATED_DART,\n'
        '    )${codegenTargets.isEmpty ? '' : ' + _CODEGEN'},\n'
        '    language_version = _LANG,\n'
        '    package_name = _PKG,\n'
        '    visibility = ["//visibility:public"],\n'
        '    deps = _PURE_DEPS + _FLUTTER_DEPS,\n'
        ')\n',
  );

  // --- tests -----------------------------------------------------------------
  // Every test file with a `main` besides the fixed ones is a target of its
  // own. A test keeps the name the BUILD file gave it; one the hand region
  // defines is the hand region's (buildgen then skips it).
  final special = {
    'test/flow_scope_test.dart',
    'test/architecture/architecture_test.dart',
    ?pkg.contract?.path,
    ?pkg.golden?.path,
  };
  final oldTestNames = <String, String>{
    for (final s in [
      ...?existing?.statements,
      ...?existing?.handStatements,
    ])
      if (s.key.startsWith('rule:'))
        if (s.attr('main') case final main?) main: s.key.substring(5),
  };
  final candidates = <DartFile>[
    for (final f in pkg.test)
      if (!special.contains(f.path) &&
          f.path.endsWith('_test.dart') &&
          !f.path.startsWith('test/feature/') &&
          RegExp(r'^void main\(', multiLine: true).hasMatch(f.text))
        f,
  ];
  String shortName(DartFile f) {
    final stem = p.posix.basenameWithoutExtension(f.path);
    return stem.startsWith('${name}_') ? stem.substring(name.length + 1) : stem;
  }

  // Two files with the same name in different directories (or a name the
  // fixed targets use) get their directories in the name:
  // test/unit/foo_test.dart -> unit_foo_test.
  final reserved = {
    name,
    'bdd_test',
    'contract_test',
    'flow_scope_test',
    'golden_test',
    'architecture_test',
    '_pure_srcs_list',
    ...oldTestNames.values,
  };
  final counts = <String, int>{};
  for (final f in candidates) {
    if (oldTestNames[f.path] == null) {
      counts[shortName(f)] = (counts[shortName(f)] ?? 0) + 1;
    }
  }
  final names = <String, String>{};
  for (final f in candidates) {
    final carried = oldTestNames[f.path];
    if (carried != null) {
      names[f.path] = carried;
      continue;
    }
    final short = shortName(f);
    names[f.path] = counts[short]! > 1 || reserved.contains(short)
        ? [
            ...p.posix.split(p.posix.dirname(f.path)).skip(1),
            short,
          ].join('_')
        : short;
  }
  final seen = <String, String>{};
  for (final e in names.entries) {
    final other = seen[e.value];
    if (other != null) {
      throw StateError(
        '${pkg.name}: the test targets of $other and ${e.key} would both be '
        'named "${e.value}"; rename one of the files',
      );
    }
    seen[e.value] = e.key;
  }
  final own = <_Test>[];
  final shared = <_Test>[];
  for (final f in candidates) {
    final t = _Test(
      names[f.path]!,
      f,
      shared: f.importsTestUtil,
      dart: !f.packages.contains('flutter_test') && f.packages.contains('test'),
    );
    (t.shared ? shared : own).add(t);
  }

  final testDeps = w.kept('var:_TEST_DEPS', '_TEST_DEPS', {
    ...labels(
      packagesOf([...pkg.steps, ...pkg.util]).difference(_bddOwn),
    ),
  });
  final testSet = testDeps.toSet();
  final media = testSet.contains(label('mc_fixtures_media'));
  const fonts = '//utility/mc_ds_theme:fonts';
  const assets = '//utility/mc_fixtures_media:asset_files';
  final env = pkg.env;
  // `_TEST_DEPS` is the BDD suite's, and every test over the env starts
  // from it (`_TEST_DEPS + [...]`): it exists whenever one of them does.
  final usesTestDeps =
      features.isNotEmpty ||
      shared.isNotEmpty ||
      pkg.golden != null ||
      pkg.file('test/flow_scope_test.dart') != null;
  if (usesTestDeps) {
    w.add(
      'var:_TEST_DEPS',
      w.listVar('_TEST_DEPS', testDeps, keptOf: 'var:_TEST_DEPS'),
      lead: '\n# --- tests (ADR-0015: BDD + contract + unit tests for pure logic; no goldens) ---\n',
    );
  }
  if (features.isNotEmpty) {
    w.add(
      'rule:bdd_test',
      'mc_bdd_tests(\n'
          '    name = "bdd_test",\n'
          '${media ? '    data = ["$assets"],\n' : ''}'
          '    features = glob(["test/feature/*.feature"]),\n'
          '    language_version = _LANG,\n'
          '    lib = ":$name",\n'
          '    package_name = _PKG,\n'
          '${env == null ? '' : '    setup = "$env",\n'}'
          '    steps = glob([\n'
          '        "test/feature/step/**/*.dart",\n'
          '        "test/feature/util/*.dart",\n'
          '    ]),\n'
          '    deps = _TEST_DEPS,\n'
          ')\n',
    );
  }

  String ownTest(
    String key,
    String tname,
    DartFile main, {
    required bool dart,
  }) {
    final deps = w.kept(key, 'deps', {':$name', ...labels(main.packages)});
    return '${dart ? 'dart_test' : 'flutter_test'}(\n'
        '    name = "$tname",\n'
        '    size = "small",\n'
        '    language_version = _LANG,\n'
        '    main = "${main.path}",\n'
        '    package_name = _PKG,\n'
        '${w.listAttr('deps', deps, keptOf: key)}'
        ')\n';
  }

  String sharedTest(
    String key,
    String tname,
    DartFile main, {
    String extra = '',
  }) {
    final deps = w.kept(key, 'deps', {
      ':$name',
      ...labels(packagesOf([main, ...pkg.util])),
    }, minus: testSet);
    return 'flutter_test(\n'
        '    name = "$tname",\n'
        '    size = "small",\n'
        '    srcs = glob(["test/feature/util/*.dart"]),\n'
        '${w.listAttr('data', [fonts, if (media) assets], suffix: extra.isEmpty ? '' : ' + $extra')}'
        '    language_version = _LANG,\n'
        '    main = "${main.path}",\n'
        '    package_name = _PKG,\n'
        '${extra.isEmpty ? '' : '    tags = ["golden"],\n    target_compatible_with = ["@platforms//os:macos"],\n'}'
        '${w.listAttr('deps', deps, keptOf: key, prefix: '_TEST_DEPS + ')}'
        ')\n';
  }

  final contract = pkg.contract;
  if (contract != null) {
    w.add(
      'rule:contract_test',
      ownTest('rule:contract_test', 'contract_test', contract, dart: false),
      lead: '\n# The DTO and the envelope against the fixture JSON (the one src/ importer, R7).\n',
    );
  }
  for (final t in own..sort((a, b) => a.file.path.compareTo(b.file.path))) {
    w.add(
      'rule:${t.name}',
      ownTest('rule:${t.name}', t.name, t.file, dart: t.dart),
    );
  }
  final flowScope = pkg.file('test/flow_scope_test.dart');
  if (flowScope != null) {
    w.add(
      'rule:flow_scope_test',
      sharedTest('rule:flow_scope_test', 'flow_scope_test', flowScope),
      lead:
          '\n# R17: the root imports resolve every registration of the flow.\n',
    );
  }
  for (final t in shared..sort((a, b) => a.file.path.compareTo(b.file.path))) {
    w.add('rule:${t.name}', sharedTest('rule:${t.name}', t.name, t.file));
  }
  final golden = pkg.golden;
  if (golden != null) {
    w.add(
      'rule:golden_test',
      sharedTest(
        'rule:golden_test',
        'golden_test',
        golden,
        extra: 'glob(["test/golden/goldens/**"], allow_empty = True)',
      ),
    );
  }
  if (pkg.file('test/architecture/architecture_test.dart') != null) {
    w.add(
      'rule:_pure_srcs_list',
      'genrule(\n'
          '    name = "_pure_srcs_list",\n'
          '    outs = ["test/architecture/pure_srcs.txt"],\n'
          '    cmd = "cat > \$@ <<\'EOF\'\\n" + "\\n".join(_PURE_SRCS) + "\\nEOF",\n'
          ')\n',
      lead:
          '\n# R4 and R15 conformance. The list of generator-read files is written from the\n'
          '# same glob as :_stage, so the check cannot drift from the staging library.\n',
    );
    w.add(
      'rule:architecture_test',
      'dart_test(\n'
          '    name = "architecture_test",\n'
          '    size = "small",\n'
          '    data = [\n'
          '        "lib/$name.dart",\n'
          '        ":_pure_srcs_list",\n'
          '    ] + _PURE_SRCS,\n'
          '    language_version = _LANG,\n'
          '    main = "test/architecture/architecture_test.dart",\n'
          '    package_name = _PKG,\n'
          '    deps = ["@pub_deps//:test"],\n'
          ')\n',
    );
  }
  return w.finish();
}

String _combining(String name, String src, String part) =>
    'dart_codegen(\n'
    '    name = "$name",\n'
    '    package_name = _PKG,\n'
    '    src = $src,\n'
    '    generator_bin = "@rules_dart//dart/ext/_shared/combining_shim:bin",\n'
    '    language_version = _LANG,\n'
    '    output_suffixes = [".g.dart"],\n'
    '    parts = [":$part"],\n'
    ')\n';

/// `# --- <title> ` padded with dashes to 78 columns.
String _rule(String title) => '# --- $title '.padRight(78, '-');
