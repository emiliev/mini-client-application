// A skeleton module's BUILD.bazel: written once from the use-graph, owned
// afterwards (P2-08's buildgen takes it over). The staging layout is the
// exemplars': pure files feed the generators, the DTO has a narrow lane.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _brick = 'feature_search_build';

/// The Flutter-free files generators read (R15): `:_stage`'s glob.
bool _isPure(SrModel m, String path) =>
    path == 'lib/src/di/di_module.dart' ||
    path == 'lib/src/di/flow_scope.dart' ||
    path.startsWith('lib/src/domain/') ||
    path == 'lib/src/flow/${m.module}_flow_state.dart' ||
    path.startsWith('lib/src/navigator/') ||
    path.startsWith('lib/src/presentation/bloc/');

String _label(EmitContext ctx, String pkg) =>
    switch (ctx.packages.lookup(pkg)) {
      FirstPartyPackage(:final dir) => '//$dir',
      _ => '@pub_deps//:$pkg',
    };

List<Map<String, String>> _labels(EmitContext ctx, Iterable<String> pkgs) {
  final labels = [for (final p in pkgs.toSet()) _label(ctx, p)]..sort();
  return [
    for (final l in labels) {'label': l},
  ];
}

Set<String> _packagesOf(UseGraph g, bool Function(String path) where) => {
  for (final l in g.libraries.values)
    if (where(l.library.path))
      for (final p in l.packages)
        if (p != g.package) p,
};

/// `# --- <title> ` padded with dashes to 78 columns.
String _rule(String title) => '# --- $title '.padRight(78, '-');

void emitSkeletonBuild(EmitContext ctx, SrModel m, Map<String, String> v) {
  final preamble = m.text(
    'build.preamble',
    '`${m.module}`: a search feature (archetype search).\n'
        'No per-package analysis_options.yaml: the root file applies (F-0021).\n'
        '\n'
        'Every generator runs as a Bazel action; nothing generated is committed.\n'
        'Generators read only Flutter-free libraries (R15): `_stage` holds the\n'
        'pure files, and the retrofit and json actions see only the DTOs\n'
        '(`_stage_dto`), so a bloc body edit re-runs neither (F-0031 fact 4).',
  );
  ctx.deferred('BUILD.bazel', (g) {
    final pure = {
      ..._packagesOf(g, (p) => _isPure(m, p)),
      'get_it',
      'json_annotation',
    };
    final lib = {
      ..._packagesOf(g, (p) => p.startsWith('lib/')),
      ...m.spec.deps,
      ...pure,
      'flutter_localizations',
      'intl',
    };
    final tests =
        _packagesOf(
          g,
          (p) =>
              p.startsWith('test/feature/step/') ||
              p.startsWith('test/feature/util/') ||
              p == 'test/flow_scope_test.dart',
        ).difference({
          'dio',
          'flutter',
          'flutter_test',
          'mc_di',
          'mc_test_steps',
          'mc_test_utils',
        });
    final contractPath = [
      for (final p in g.libraries.keys)
        if (p.startsWith('test/contract/')) p,
    ].single;
    final contract = _packagesOf(g, (p) => p == contractPath);
    String freezedName(String path) {
      final stem = path.split('/').last.replaceFirst('.dart', '');
      if (stem == '${m.module}_flow_state') return 'flow_state';
      if (stem == '${m.module}_bloc') return 'search_bloc';
      return stem;
    }

    final freezed = <(String, String)>[
      for (final l in g.libraries.values)
        if (l.library.parts.any((p) => p.endsWith('.freezed.dart')))
          (freezedName(l.library.path), l.library.path),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final dtoName = v['dtoFile']!.replaceFirst('.dart', '');
    final apiName = '${m.module}_api';
    final codegen =
        <(String, String)>[
          for (final (name, _) in freezed) (name, '_${name}_freezed'),
          (dtoName, '_${dtoName}_g'),
          (apiName, '_${apiName}_g'),
        ]..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });
    final injectable = [
      for (final l in g.libraries.values)
        if (l.library.path.startsWith('lib/') &&
            l.imports.contains('package:injectable/injectable.dart') &&
            !l.library.path.endsWith('/di_initializer.dart') &&
            !l.library.path.contains('/model/'))
          l.library.path,
    ]..sort();
    return ctx.bricks[_brick].render({
      'build_file': 'BUILD.bazel',
      'build_preamble': commentLines(
        preamble,
      ).replaceAll(RegExp('^//', multiLine: true), '#'),
      'name': m.module,
      'pascal': m.pascal,
      'lang': ctx.config.languageVersion,
      'pure_deps': _labels(ctx, pure),
      'flow_state_src': 'lib/src/flow/${m.module}_flow_state.dart',
      'freezed': [
        for (final (name, src) in freezed) {'name': name, 'src': src},
      ],
      'dto_name': dtoName,
      'dto_src': 'lib/src/domain/model/${v['dtoFile']}',
      'dto_rule': _rule('$dtoName: json over the freezed output'),
      'api_rule': _rule('$apiName: retrofit (fork patch 0001)'),
      'api_name': apiName,
      'api_src': 'lib/src/domain/api/$apiName.dart',
      'injectable': [
        for (final s in injectable) {'src': s},
      ],
      'codegen': [
        for (final (_, t) in codegen) {'target': ':$t'},
        {'target': ':di_config'},
        {'target': ':_l10n'},
      ],
      'flutter_deps': _labels(ctx, lib.difference(pure)),
      'test_deps': _labels(ctx, tests),
      'env': 'test/feature/util/${m.module}_env.dart',
      'contract_main': contractPath,
      'contract_deps': [
        {'label': ':${m.module}'},
        ..._labels(ctx, contract),
      ],
    })['BUILD.bazel']!;
  }, owned: true);
}
