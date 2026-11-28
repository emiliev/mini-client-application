// A skeleton module's BUILD.bazel: written once from the use-graph, owned
// afterwards (P2-08's buildgen takes it over).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/text.dart';

const _brick = 'feature_form_wizard_build';

/// The Flutter-free files generators read (R15): `:_stage`'s glob.
bool _isPure(FwModel m, String path) =>
    path == 'lib/src/di/flow_scope.dart' ||
    path.startsWith('lib/src/domain/') ||
    path == 'lib/src/flow/${m.stem}_flow_state.dart' ||
    path.startsWith('lib/src/navigator/') ||
    path.startsWith('lib/src/presentation/bloc/') ||
    path.startsWith('lib/src/presentation/form/');

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

void emitSkeletonBuild(EmitContext ctx, FwModel m) {
  final preamble = m.text(
    'build.preamble',
    '`${m.module}`: a form/wizard feature (archetype form_wizard).\n'
        'No per-package analysis_options.yaml: the root file applies (F-0021).\n'
        '\n'
        'Every generator runs as a Bazel action; nothing generated is committed.\n'
        'Generators read only Flutter-free libraries (R15): `_stage` holds the\n'
        'pure files.',
  );
  ctx.deferred('BUILD.bazel', (g) {
    final pure = {
      ..._packagesOf(g, (p) => _isPure(m, p)),
      'get_it',
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
          'flutter',
          'flutter_test',
          'mc_monitoring',
          'mc_storage',
          'mc_test_steps',
          'mc_test_utils',
        });
    final freezed = <(String, String)>[
      for (final l in g.libraries.values)
        if (l.library.parts.any((p) => p.endsWith('.freezed.dart')))
          (
            l.library.path.endsWith('_flow_state.dart')
                ? 'flow_state'
                : l.library.path.split('/').last.replaceFirst('.dart', ''),
            l.library.path,
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
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
      'l10n_file': m.l10nFile,
      'stem': m.stem,
      'lang': ctx.config.languageVersion,
      'pure_deps': _labels(ctx, pure),
      'freezed': [
        for (final (name, src) in freezed) {'name': name, 'src': src},
      ],
      'injectable': [
        for (final s in injectable) {'src': s},
      ],
      'codegen': [
        for (final (name, _) in freezed) {'target': ':_${name}_freezed'},
        {'target': ':di_config'},
        {'target': ':_l10n'},
      ],
      'flutter_deps': _labels(ctx, lib.difference(pure)),
      'test_deps': _labels(ctx, tests),
      'env': 'test/feature/util/${m.stem}_env.dart',
    })['BUILD.bazel']!;
  }, owned: true);
}
