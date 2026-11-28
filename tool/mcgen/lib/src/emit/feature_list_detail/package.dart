// The list-detail package files: pubspec.yaml and BUILD.bazel (their lists
// come from the generated code's use-graph), l10n.yaml, the ARBs and the
// `.feature` files.

import 'dart:convert';

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_list_detail/common.dart';
import 'package:mcgen/src/emit/feature_list_detail/model.dart';

const _brick = 'feature_list_detail_package';

/// The Flutter-free files generators read (R15): `:_stage`'s glob.
bool _isPure(LdModel m, String path) =>
    path == 'lib/src/di/flow_scope.dart' ||
    path.startsWith('lib/src/domain/') ||
    path == 'lib/src/flow/${m.module}_flow_state.dart' ||
    path.startsWith('lib/src/navigator/') ||
    path.startsWith('lib/src/presentation/bloc/');

void emitPackage(EmitContext ctx, LdModel m) {
  for (final f in m.spec.bdd) {
    ctx.file('test/feature/${f.feature}.feature', renderFeature(f));
  }
  _arbs(ctx, m);
  for (final path in ['pubspec.yaml', 'BUILD.bazel', 'l10n.yaml']) {
    ctx.deferred(
      path,
      (graph) => ctx.bricks[_brick].render(_vars(ctx, m, graph))[path]!,
    );
  }
}

void _arbs(EmitContext ctx, LdModel m) {
  final l10n = m.spec.l10n!;
  for (final locale in l10n.locales) {
    final template = locale == l10n.locales.first;
    final lines = [
      '"@@locale": ${jsonEncode(locale)}',
      for (final s in l10n.strings) ...[
        '${jsonEncode(s.key)}: ${jsonEncode(s.text[locale] ?? pseudo(s.text[l10n.locales.first]!))}',
        if (template && s.description != null)
          '${jsonEncode('@${s.key}')}: {"description": ${jsonEncode(s.description)}}',
      ],
    ];
    ctx.file(
      'lib/src/l10n/${m.module}_$locale.arb',
      '{\n${lines.map((l) => '  $l').join(',\n')}\n}\n',
    );
  }
}

/// A pseudo-translation (en_XA, R24): accented, bracketed and about 40 %
/// longer, so truncation and hard-coded strings show up in tests.
String pseudo(String text) {
  const accents = {
    'a': 'à', 'b': 'ƀ', 'c': 'ç', 'd': 'ð', 'e': 'é', 'f': 'f', 'g': 'ĝ', //
    'h': 'ĥ', 'i': 'í', 'j': 'ĵ', 'k': 'ķ', 'l': 'ļ', 'm': 'ɱ', 'n': 'ñ', //
    'o': 'ó', 'p': 'þ', 'q': 'ǫ', 'r': 'ŕ', 's': 'š', 't': 'ţ', 'u': 'ú', //
    'v': 'ṽ', 'w': 'ŵ', 'x': 'ẋ', 'y': 'ý', 'z': 'ž', 'A': 'À', 'C': 'Ç', //
    'D': 'Ð', 'E': 'É', 'G': 'Ĝ', 'H': 'Ĥ', 'I': 'Í', 'L': 'Ļ', 'N': 'Ñ', //
    'O': 'Ó', 'S': 'Š', 'T': 'Ţ', 'U': 'Ú', 'Y': 'Ý', 'Z': 'Ž',
  };
  final accented = text.split('').map((c) => accents[c] ?? c).join();
  return '[$accented ${'~' * (text.length * 2 / 5).ceil()}]';
}

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
String _rule(String title) {
  final head = '# --- $title ';
  return head.padRight(78, '-');
}

Map<String, Object?> _vars(EmitContext ctx, LdModel m, UseGraph g) {
  final spec = m.spec;
  final hasJson = m.dtos.isNotEmpty;
  // Codegen runtimes the source never names: injectable's output uses get_it
  // and json_serializable's json_annotation; gen-l10n's output uses
  // flutter_localizations and intl.
  final pure = {
    ..._packagesOf(g, (p) => _isPure(m, p)),
    'get_it',
    if (hasJson) 'json_annotation',
  };
  final lib = {
    ..._packagesOf(g, (p) => p.startsWith('lib/')),
    ...spec.deps,
    ...pure,
    'flutter_localizations',
    'intl',
  };
  final bdd = _packagesOf(
    g,
    (p) =>
        p.startsWith('test/feature/step/') ||
        p.startsWith('test/feature/util/') ||
        p == 'test/flow_scope_test.dart',
  );
  // flow_scope_test adds these itself (with the library and Flutter): the DI
  // and the Dio of its root-without-a-type case.
  const flowScopeOwn = {
    'mc_di',
    'dio',
    'flutter',
    'flutter_test',
    'mc_test_utils',
  };
  final tests = bdd.difference(flowScopeOwn);
  final testFiles = _packagesOf(g, (p) => !p.startsWith('lib/'));
  final dev = {
    ...testFiles.difference(lib),
    ...spec.devDeps,
    'mc_analysis',
    'mc_test_steps',
  };
  final contractPath = [
    for (final p in g.libraries.keys)
      if (p.startsWith('test/contract/')) p,
  ].single;
  final contract = _packagesOf(g, (p) => p == contractPath);

  final freezed = <(String, String)>[
    for (final l in g.libraries.values)
      if (l.library.parts.any((p) => p.endsWith('.freezed.dart')))
        (_freezedName(m, l.library.path), l.library.path),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final dtoSrc = 'lib/src/domain/model/${m.dtoFile}';
  final dtoName = m.dtoFile.replaceFirst('.dart', '');
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
  String entry(String p) => ctx.packages.pubspecEntry(p);
  final description = spec.description;
  if (description == null) {
    throw StateError('${spec.file}: list_detail needs a description');
  }
  return {
    'pubspec_preamble': m.prose['pubspec.preamble'] == null
        ? ''
        : commentLines(m.prose['pubspec.preamble']!).replaceAll('//', '#'),
    'build_preamble': commentLines(
      m.text(
        'build.preamble',
        '${m.module}: a list-detail feature (archetype list_detail).\n'
            'No per-package analysis_options.yaml: the root file applies (F-0021).\n'
            '\n'
            'Every generator runs as a Bazel action; nothing generated is committed.\n'
            'Generators read only Flutter-free libraries (R15): `_stage` holds the\n'
            'pure files, and the retrofit and json actions see only the DTOs\n'
            '(`_stage_dto`), so a bloc body edit re-runs neither (F-0031 fact 4).',
      ),
    ).replaceAll(RegExp('^//', multiLine: true), '#'),
    'name': m.module,
    'pascal': m.pascal,
    'description': description,
    'sdk': ctx.config.sdkConstraint,
    'flutter': ctx.config.flutterConstraint ?? '^3.47.7',
    'dependencies': [
      for (final p in (lib.toList()..sort())) {'entry': entry(p)},
    ],
    'dev_dependencies': [
      for (final p in (dev.toList()..sort())) {'entry': entry(p)},
    ],
    'pure_deps': _labels(ctx, pure),
    'flow_state_src': 'lib/src/flow/${m.module}_flow_state.dart',
    'freezed': [
      for (final (name, src) in freezed) {'name': name, 'src': src},
    ],
    'dto_name': dtoName,
    'dto_src': dtoSrc,
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
    'legacy_goldens': m.tests.legacyGoldens,
    'golden_main': 'test/golden/${m.module}_golden_test.dart',
  };
}

/// The flow state is `flow_state`, the list page's bloc `list_bloc`, any
/// other file its stem: the names the exemplar's BUILD gives its freezed
/// targets.
String _freezedName(LdModel m, String path) {
  final stem = path.split('/').last.replaceFirst('.dart', '');
  if (stem == '${m.module}_flow_state') return 'flow_state';
  if (stem == '${m.module}_bloc') return 'list_bloc';
  return stem;
}
