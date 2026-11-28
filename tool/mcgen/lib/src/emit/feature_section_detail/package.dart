// The section-detail package files: pubspec.yaml and BUILD.bazel (their lists
// (T-0074: BUILD.bazel is `mcgen buildgen`'s now; the brick still renders
// the old one, which is dropped, until the template goes: F-0074 §6)
// come from the generated code's use-graph, plus what the exemplars' owned
// files use), l10n.yaml, the ARBs and the `.feature` files.

import 'dart:convert';

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/use_graph.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_list_detail/package.dart' show pseudo;
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:mcgen/src/emit/feature_section_detail/model.dart';

const _brick = 'feature_section_detail_package';

/// The Flutter-free files generators read (R15): `:_stage`'s glob.
bool _isPure(ScModel m, String path) =>
    path == 'lib/src/di/flow_scope.dart' ||
    path.startsWith('lib/src/domain/') ||
    path == 'lib/src/flow/${m.module}_flow_state.dart' ||
    path.startsWith('lib/src/navigator/') ||
    path.startsWith('lib/src/presentation/bloc/');

void emitPackage(EmitContext ctx, ScModel m) {
  for (final f in m.spec.bdd) {
    ctx.file(
      'test/feature/${f.feature}.feature',
      renderFeature(f, rules: {for (final r in m.spec.rules) r.id: r}),
    );
  }
  _arbs(ctx, m);
  // Read now, not when the deferred files are built, so the archetype's
  // unused-prose check sees these slots.
  final pubspec = m.optionalText('pubspec.preamble');
  final build = m.text(
    'build.preamble',
    '${m.module}: a section-detail feature (archetype section_detail).\n'
        'No per-package analysis_options.yaml: the root file applies (F-0021).\n'
        '\n'
        'Every generator runs as a Bazel action; nothing generated is committed.\n'
        'Generators read only Flutter-free libraries (R15): `_stage` holds the\n'
        'pure files, and the retrofit and json actions see only the DTOs\n'
        '(`_stage_dto`), so a bloc body edit re-runs neither.',
  );
  final testsRule = m.text(
    'build.tests_rule',
    '# --- tests (ADR-0015: BDD + contract + unit tests for pure logic; no goldens) ---',
  );
  final apiRule = m.text(
    'build.api_rule',
    _rule('${m.module}_api: retrofit (fork patch 0001)'),
  );
  for (final path in ['pubspec.yaml', 'l10n.yaml']) {
    ctx.deferred(
      path,
      (graph) => ctx.bricks[_brick].render(
        _vars(
          ctx,
          m,
          graph,
          pubspec: pubspec,
          build: build,
          testsRule: testsRule,
          apiRule: apiRule,
        ),
      )[path]!,
    );
  }
}

void _arbs(EmitContext ctx, ScModel m) {
  final l10n = m.spec.l10n!;
  final first = l10n.locales.first;
  String textOf(L10nStringSpec s, String locale) {
    final text = s.text[locale];
    if (text != null) return text;
    if (locale != 'en_XA') {
      throw StateError('${s.path}: "${s.key}" has no "$locale" text');
    }
    final source = s.text[first];
    if (source == null) {
      throw StateError(
        '${s.path}: "${s.key}" has no "$first" text to pseudo-translate',
      );
    }
    return pseudo(source);
  }

  // The exemplars' hand format: a description alone on the entry's line, a
  // description with placeholders on three lines.
  String meta(L10nStringSpec s, String key) {
    final desc = s.description == null
        ? null
        : '"description": ${jsonEncode(s.description)}';
    final ph = s.placeholders.isEmpty
        ? null
        : '"placeholders": ${_spaced(s.placeholders)}';
    if (ph == null) return '${jsonEncode('@$key')}: {${desc ?? ''}}';
    return '${jsonEncode('@$key')}: {\n'
        '${[?desc, ph].map((l) => '    $l').join(',\n')}\n'
        '  }';
  }

  for (final locale in l10n.locales) {
    final template = locale == first;
    final lines = [
      '"@@locale": ${jsonEncode(locale)}',
      for (final s in l10n.strings) ...[
        '${jsonEncode(s.key)}: ${jsonEncode(textOf(s, locale))}',
        if (template && (s.description != null || s.placeholders.isNotEmpty))
          meta(s, s.key),
      ],
    ];
    ctx.file(
      'lib/src/l10n/${m.module}_$locale.arb',
      '{\n${lines.map((l) => '  $l').join(',\n')}\n}\n',
    );
  }
}

/// JSON with a space after `:` and `,` inside maps, as the exemplars write
/// `{"number": {"type": "int"}}`.
String _spaced(Object? v) => switch (v) {
  Map() =>
    '{${[for (final e in v.entries) '${jsonEncode('${e.key}')}: ${_spaced(e.value)}'].join(', ')}}',
  _ => jsonEncode(v),
};

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

String _hash(String commentText) => commentLines(
  commentText,
).replaceAll(RegExp('^//', multiLine: true), '#').trimRight();

Map<String, Object?> _vars(
  EmitContext ctx,
  ScModel m,
  UseGraph g, {
  required String? pubspec,
  required String build,
  required String testsRule,
  required String apiRule,
}) {
  final spec = m.spec;
  // Codegen runtimes the source never names: injectable's output uses get_it
  // and json_serializable's json_annotation; gen-l10n's output uses
  // flutter_localizations and intl.
  final pure = {
    ..._packagesOf(g, (p) => _isPure(m, p)),
    ...m.buildPure,
    'get_it',
    'json_annotation',
  };
  final lib = {
    ..._packagesOf(g, (p) => p.startsWith('lib/')),
    ...spec.deps,
    ...pure,
    'flutter_localizations',
    'intl',
    // The root-import list's (`lib/src/di/flow_scope.dart`, which `mcgen
    // wire` writes since T-0074): Dio, EventBus, Monitoring (and the
    // analytics port), SessionReader, over mc_di's RootImport.
    'dio',
    'mc_di',
    'mc_event_bus',
    'mc_monitoring',
    'mc_session',
  };
  final bdd = {
    ..._packagesOf(
      g,
      (p) =>
          p.startsWith('test/feature/step/') ||
          p.startsWith('test/feature/util/') ||
          p == 'test/flow_scope_test.dart',
    ),
    ...m.buildTests,
  };
  final tests = bdd.difference(m.buildFlowScope.toSet());
  final testFiles = _packagesOf(g, (p) => !p.startsWith('lib/'));
  final dev = {
    ...testFiles.difference(lib),
    ...spec.devDeps,
    'mc_analysis',
    'mc_test_steps',
  };
  final freezed = <(String, String)>[
    for (final l in g.libraries.values)
      if (l.library.parts.any((p) => p.endsWith('.freezed.dart')))
        (_freezedName(m, l.library.path), l.library.path),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final dtoSrc = 'lib/src/domain/model/${m.dtoFile}';
  final dtoName = m.dtoFile.replaceFirst('.dart', '');
  final apiName = '${m.module}_api';
  // The exemplars' order: the domain models, then the DTO's json and the
  // API's retrofit output, then the flow state and the blocs.
  bool model((String, String) f) => f.$2.startsWith('lib/src/domain/model/');
  final codegen = <(String, String)>[
    for (final (name, _) in freezed.where(model)) (name, '_${name}_freezed'),
    (dtoName, '_${dtoName}_g'),
    (apiName, '_${apiName}_g'),
    for (final (name, _) in freezed.where((f) => !model(f)))
      (name, '_${name}_freezed'),
  ];
  final injectable = [
    for (final l in g.libraries.values)
      if (l.library.path.startsWith('lib/') &&
          l.imports.contains('package:injectable/injectable.dart') &&
          !l.library.path.endsWith('/di_initializer.dart') &&
          !l.library.path.contains('/model/'))
        l.library.path,
  ]..sort();
  String entry(String p) => ctx.packages.pubspecEntry(p);
  final description = spec.description!;
  return {
    'pubspec_preamble': pubspec == null ? '' : '${_hash(pubspec)}\n',
    'build_preamble': '${_hash(build)}\n',
    'build_file': 'BUILD.bazel',
    'name': m.module,
    'pascal': m.prefix,
    'l10n_class': m.l10nClass,
    'tests_rule': testsRule,
    'description': description,
    'sdk': ctx.config.sdkConstraint,
    'flutter':
        ctx.config.flutterConstraint ??
        (throw StateError(
          'tool/mcgen/mcgen.yaml needs dart.flutter_constraint for a Flutter feature',
        )),
    'lang': ctx.config.languageVersion,
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
    'api_rule': apiRule,
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
    'env': m.envFile,
    'contracts': [
      for (final c in m.tests.contracts)
        {
          'comment': _hash(c.comment),
          'name': c.name,
          'main': c.main,
          'deps': [
            for (final d in c.deps) {'label': d},
          ],
        },
    ],
    'flow_scope_deps': [
      {'label': ':${m.module}'},
      ..._labels(ctx, m.buildFlowScope),
    ],
    'legacy_goldens': m.tests.legacyGoldens,
    'golden_main': 'test/golden/${m.module}_golden_test.dart',
  };
}

/// The flow state is `flow_state`, the details bloc `details_bloc`, the
/// favourite bloc `favourite_bloc`, any other file its stem: the names the
/// exemplars' BUILD gives its freezed targets.
String _freezedName(ScModel m, String path) {
  final stem = path.split('/').last.replaceFirst('.dart', '');
  if (stem == '${m.module}_flow_state') return 'flow_state';
  if (stem == '${snakeCase(m.item)}_details_bloc') return 'details_bloc';
  if (stem == '${snakeCase(m.item)}_favourite_bloc') return 'favourite_bloc';
  return stem;
}
