// The dashboard's flow layer: the barrel, the ids, DI, the root-import list,
// the navigator contract, the flow state, the flow, the analytics vocabulary,
// the flags and the clock (Tide nav 3.3, 3.4; ADR-0012).

import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';

void emitFlow(Out ctx, DbModel m) {
  _barrel(ctx, m);
  for (final id in m.ids) {
    ctx.file(
      'lib/src/domain/model/${id.file}',
      '${docBlock(id.doc)}extension type const ${id.name}(${id.type} value) {}\n',
    );
  }
  ctx.file('lib/src/di/di_initializer.dart', _di(m));
  ctx.file('lib/src/di/flow_scope.dart', _flowScope(m));
  ctx.file('lib/src/navigator/${m.module}_navigator.dart', _navigator(m));
  ctx.file('lib/src/flow/${m.module}_flow_state.dart', _flowState(m));
  ctx.file('lib/src/flow/${m.module}_flow.dart', _flow(m));
  ctx.file('lib/src/domain/model/${m.analyticsFile}', _analytics(m));
  if (m.flags.isNotEmpty) {
    ctx.file('lib/src/flags/${m.module}_flags.dart', _flags(m));
  }
  if (m.hasClock) {
    ctx.file('lib/src/domain/model/${m.clockFile}', _clock(m));
  }
}

void _barrel(Out ctx, DbModel m) {
  final exports = <String, List<String>>{
    for (final id in m.ids)
      if (m.barrel.contains(id.name))
        m.uri('domain/model/${id.file}'): [id.name],
    m.uri('flow/${m.module}_flow.dart'): [m.flow],
    m.uri('navigator/${m.module}_navigator.dart'): [m.navigator],
  };
  final preamble = commentLines(
    m.text(
      'barrel.preamble',
      'The public surface (R4, checked by mc_arch_check and the architecture\n'
          "test): the flow, its navigator and the navigator's argument types. No\n"
          "`library;` directive (Tide's `unnecessary_library_directive`).",
    ),
  );
  final uris = exports.keys.toList()..sort();
  ctx.file(
    'lib/${m.module}.dart',
    '$preamble${[for (final u in uris) "export '$u' show ${(exports[u]!..sort()).join(', ')};"].join('\n')}\n',
  );
}

String _di(DbModel m) => tpl(
  '''
import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';
import '<<config_uri>>';

/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate shape; plan 01 §3.3).
class <<DIInitializer>> extends McDIInitializer {
  const <<DIInitializer>>() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
''',
  {
    'config_uri': m.uri('di/di_initializer.config.dart'),
    'DIInitializer': m.diInitializer,
  },
);

String _flowScope(DbModel m) {
  final roots = <(String, String)>[
    ('AnalyticsTracker', 'package:mc_monitoring/mc_monitoring.dart'),
    ('Dio', 'package:dio/dio.dart'),
    if (m.flags.isNotEmpty)
      ('FeatureFlagsReader', 'package:mc_feature_flags/mc_feature_flags.dart'),
    ('Monitoring', 'package:mc_monitoring/mc_monitoring.dart'),
    if (m.hasSession) ('SessionReader', 'package:mc_session/mc_session.dart'),
  ];
  final provided = [
    '`FeatureFlowController`',
    'the navigator',
    if (m.hasClock) 'the `${m.clock}`',
  ];
  final providedText = provided.length == 1
      ? provided.single
      : '${provided.take(provided.length - 1).join(', ')}, ${provided.last}';
  return tpl(
    '''
<<imports>>

<<d_doc>>const List<RootImport<Object>> <<rootImports>> = [
<<roots>>
];
''',
    {
      'imports': imports([
        'package:mc_di/mc_di.dart',
        for (final r in roots) r.$2,
      ]),
      'd_doc': m.doc(
        'flow_scope.doc',
        'The root services this flow\'s container forwards (R17): the parameter\n'
            'types of every injectable constructor and `@factoryMethod` in the\n'
            'package, minus what the package registers itself and what the flow\n'
            'provides ($providedText).\n'
            '\n'
            'HAND-WRITTEN FOR NOW. Plan 01 §4.5 has `mcgen wire` derive this file from\n'
            'the same analyzer input injectable reads, and `mcgen check` fail on drift\n'
            '(Phase D). Until then `test/flow_scope_test.dart` opens the flow over the\n'
            'production-shaped test root and resolves every registration, so a missing\n'
            'import fails a test, not the app.',
      ),
      'rootImports': m.rootImports,
      'roots': [for (final r in roots) '  RootImport<${r.$1}>(),'].join('\n'),
    },
  );
}

String _navigator(DbModel m) {
  final nav = m.spec.navigator!;
  final argUris = {
    for (final o in nav.outbound)
      for (final a in o.args)
        if (m.idOf(a) case final id?) m.uri('domain/model/${id.file}'),
  };
  final methods = [
    for (final o in nav.outbound)
      '  ${m.memberDoc('navigator.${o.name}', 'Leaves the feature: ${o.name}.')}'
          '${o.returns ?? 'void'} ${o.name}(${[for (final a in o.args) '$a ${m.param(o.name)}'].join(', ')});',
  ];
  return '${imports(argUris)}${argUris.isEmpty ? '' : '\n\n'}'
      '${docBlock(nav.doc)}abstract interface class ${m.navigator} {\n'
      '${methods.join('\n\n')}\n}\n';
}

String _flowState(DbModel m) {
  final d = m.detail;
  final head =
      '${imports(['package:freezed_annotation/freezed_annotation.dart', if (d != null) m.uri('domain/model/${m.idOf(d.id)!.file}')])}\n\n'
      "part '${m.module}_flow_state.freezed.dart';\n\n";
  final cls = m.doc(
    'flow_state.doc',
    'What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,\n'
        'so the blocs that update it stay Flutter-free (R15).',
  );
  if (d == null) {
    return '$head$cls@freezed\n'
        'abstract class ${m.flowState} with _\$${m.flowState} {\n'
        '  const factory ${m.flowState}() = _${m.flowState};\n'
        '}\n';
  }
  return '$head$cls@freezed\n'
      'abstract class ${m.flowState} with _\$${m.flowState} {\n'
      '  const factory ${m.flowState}({\n'
      '${m.doc('flow_state.root', 'The flow opened at this ${d.name}: its page is the only page, so Back\nleaves the flow.').split('\n').where((l) => l.isNotEmpty).map((l) => '    $l\n').join()}'
      '    ${d.open}? root${d.pascal},\n'
      '\n'
      '${m.doc('flow_state.current', 'The ${d.name} whose page is open above the home.').split('\n').where((l) => l.isNotEmpty).map((l) => '    $l\n').join()}'
      '    ${d.open}? ${d.name},\n'
      '  }) = _${m.flowState};\n'
      '}\n\n'
      '${m.doc('flow_state.open', 'A ${d.name} page to show: its id, and its name when the opener knew it.')}'
      '@freezed\n'
      'abstract class ${d.open} with _\$${d.open} {\n'
      '  const factory ${d.open}({required ${d.id} id, String? name}) =\n'
      '      _${d.open};\n'
      '}\n';
}

String _flow(DbModel m) {
  final d = m.detail;
  final uris = [
    'package:flutter/widgets.dart',
    'package:mc_analytics/mc_analytics.dart',
    'package:mc_feature_flow/mc_feature_flow.dart',
    'package:mc_monitoring/mc_monitoring.dart',
    m.uri('di/di_initializer.dart'),
    m.uri('di/flow_scope.dart'),
    m.uri('domain/model/${m.analyticsFile}'),
    if (m.hasClock) m.uri('domain/model/${m.clockFile}'),
    m.uri('flow/${m.module}_flow_state.dart'),
    m.uri('l10n/${m.module}_l10n.dart'),
    m.uri('navigator/${m.module}_navigator.dart'),
    if (d != null) ...[
      m.uri('domain/model/${m.idOf(d.id)!.file}'),
      m.uri('presentation/page/${d.name}_page.dart'),
    ],
    m.uri('presentation/page/${m.module}_page.dart'),
  ];
  final provides = [
    'registerSingleton<${m.navigator}>(navigator)',
    if (m.hasClock) 'registerSingleton<${m.clock}>(${m.clock}(clock))',
  ];
  final provide = provides.length == 1
      ? 'scope.${provides.single}'
      : 'scope\n${provides.map((p) => '      ..$p').join('\n')}';
  final cls = m.doc(
    'flow.doc',
    "The feature's only entry point (R4): the ${m.module.replaceAll('_', ' ')} in "
        'independent sections, whose items leave the feature through\n'
        '[navigator].\n'
        '\n'
        'The app builds it from a route with the navigator implementation from its\n'
        'wiring; tests pass a mock.\n'
        '\n'
        'Immutable after creation: the flow reads [navigator] once, when its\n'
        'scope opens (`provide:` runs once per flow instance).',
  );
  final ctor = [
    '    required this.navigator,',
    if (m.hasClock) '    required this.clock,',
    if (d != null) '    this.initial${d.pascal},',
    '    super.key,',
  ].join('\n');
  final fields = [
    'final ${m.navigator} navigator;',
    if (m.hasClock)
      '${m.doc('flow.clock', 'The time countdowns count against.')}final DateTime Function() clock;',
    if (d != null)
      '${m.doc('flow.initial', 'Opens the flow at this ${d.name}: its page is the only one, so Back\nleaves the flow.')}final ${d.id}? initial${d.pascal};',
  ].join('\n\n');
  final state = d == null
      ? 'const ${m.flowState}()'
      : '${m.flowState}(\n'
            '      root${d.pascal}: switch (initial${d.pascal}) {\n'
            '        final id? => ${d.open}(id: id),\n'
            '        null => null,\n'
            '      },\n'
            '    )';
  final pages = d == null
      ? "const McFlowPage(name: ${m.camel}Screen, child: ${m.homePage}())"
      : 'if (state.root${d.pascal} case final root?)\n'
            '        McFlowPage(\n'
            '          name: ${m.kCamel}${d.pascal}Screen,\n'
            '          arguments: root.id,\n'
            '          child: ${d.pascal}Page(key: ValueKey(root.id), ${d.name}: root),\n'
            '        )\n'
            '      else ...[\n'
            '        const McFlowPage(name: ${m.camel}Screen, child: ${m.homePage}()),\n'
            '        if (state.${d.name} case final ${d.name}?)\n'
            '          McFlowPage(\n'
            '            name: ${m.kCamel}${d.pascal}Screen,\n'
            '            arguments: ${d.name}.id,\n'
            '            child: ${d.pascal}Page(\n'
            '              key: ValueKey(${d.name}.id),\n'
            '              ${d.name}: ${d.name},\n'
            '            ),\n'
            '          ),\n'
            '      ]';
  return tpl(
    '''
<<imports>>

<<d_class>>class <<Flow>> extends StatelessWidget {
  const <<Flow>>({
<<ctor>>
  });

<<fields>>

  @override
  Widget build(BuildContext context) => FeatureFlow<<<FlowState>>>(
<<key>>    flowInitializer: const <<DIInitializer>>(),
    rootImports: <<rootImports>>,
    provide: (scope) => <<provide>>,
    localizationsDelegates: const [<<L10n>>.delegate],
    // The flow's pages are screens (P-103): resolved inside the flow.
    observers: [
      AnalyticsFlowObserver(
        (context) => context.di<AnalyticsTracker>(),
        // Without a dependency on the host route (F-0056 §4).
        host: (context) => FlowScope.read(context).outerRoute,
      ),
    ],
    state: <<state>>,
    onGeneratePages: (state) => [
      <<pages>>,
    ],
  );
}
''',
    {
      'imports': imports(uris),
      'd_class': cls,
      'Flow': m.flow,
      'ctor': ctor,
      'fields': fields,
      'key': d == null ? '' : '    key: ValueKey(initial${d.pascal}),\n',
      'FlowState': m.flowState,
      'DIInitializer': m.diInitializer,
      'rootImports': m.rootImports,
      'provide': provide,
      'L10n': m.l10nClass,
      'state': state,
      'pages': pages,
    },
  );
}

String _analytics(DbModel m) {
  final d = m.detail;
  final values = [
    for (final s in m.sections) "  ${s.name}('${snakeCase(s.name)}'),",
    if (d != null) ...[
      '',
      ...m
          .doc(
            'analytics.detail_doc',
            "The ${d.name} page's ${d.items} (not a section of the home, so it\nhas no `${m.viewedEvent}`).",
          )
          .split('\n')
          .where((l) => l.isNotEmpty)
          .map((l) => '  $l'),
      "  ${d.analytics}('${snakeCase(d.analytics)}');",
    ],
  ];
  // The last value ends the list: `;` instead of `,`.
  if (d == null) {
    values[values.length - 1] = values.last.replaceFirst(RegExp(r',$'), ';');
  }
  final screens = StringBuffer()
    ..write(
      m.doc(
        'analytics.screens',
        "The screen names of the flow's pages: their `McFlowPage` names, which\n"
            '`AnalyticsFlowObserver` tracks. The first equals the app route\'s name,\n'
            'so it is not tracked twice.',
      ),
    )
    ..writeln("const String ${m.camel}Screen = '${m.screenHome}';");
  if (d != null) {
    screens.writeln(
      "const String ${m.kCamel}${d.pascal}Screen = '${m.screenDetail}';",
    );
  }
  return tpl(
    '''
import 'package:mc_monitoring/mc_monitoring.dart';

<<screens>>
<<d_viewed>>const String <<kCamel>>SectionViewedEvent = '<<viewed>>';

<<d_tapped>>const String <<kCamel>>ItemTappedEvent = '<<tapped>>';

<<d_section>>enum <<Section>> {
<<values>>

  const <<Section>>(this.wireName);

  final String wireName;
}

<<d_kind>>enum <<ItemKind>> {
<<kinds>>

  const <<ItemKind>>(this.wireName);

  final String wireName;
}

<<d_tracking>>extension <<Tracking>> on AnalyticsTracker {
  <<d_section_viewed>>void sectionViewed(<<Section>> section) =>
      trackEvent(<<kCamel>>SectionViewedEvent, {'section': section.wireName});

  <<d_item_tapped>>void itemTapped(<<Section>> section, <<ItemKind>> kind, String id) =>
      trackEvent(<<kCamel>>ItemTappedEvent, {
        'section': section.wireName,
        'kind': kind.wireName,
        'id': id,
      });
}
''',
    {
      'screens': screens.toString(),
      'd_viewed': m.doc(
        'analytics.viewed',
        'A section reached `ready` for the first time in this visit.',
      ),
      'd_tapped': m.doc('analytics.tapped', 'An item was tapped.'),
      'kCamel': m.kCamel,
      'viewed': m.viewedEvent,
      'tapped': m.tappedEvent,
      'd_section': m.doc(
        'analytics.section',
        'Where on the page something was seen or tapped: the analytics\n`section` parameter.',
      ),
      'Section': m.section,
      'values': values.join('\n'),
      'd_kind': m.doc(
        'analytics.kind',
        'What a tapped item leads to: the analytics `kind` parameter.',
      ),
      'ItemKind': m.itemKind,
      'kinds': [
        for (final (i, k) in m.kinds.indexed)
          "  $k('$k')${i == m.kinds.length - 1 ? ';' : ','}",
      ].join('\n'),
      'd_tracking': m.doc(
        'analytics.tracking',
        'The analytics vocabulary over the blocs\' pure-Dart port\n'
            '(`AnalyticsTracker`, R15): event names and params are spelled once, here.',
      ),
      'Tracking': m.tracking,
      'd_section_viewed': m.memberDoc(
        'analytics.section_viewed',
        '`${m.viewedEvent}` with `section`.',
      ),
      'd_item_tapped': m.memberDoc(
        'analytics.item_tapped',
        '`${m.tappedEvent}` with `section`, `kind` and `id` (the target\'s id).',
      ),
    },
  );
}

String _flags(DbModel m) =>
    '${imports(['package:mc_feature_flags/mc_feature_flags.dart'])}\n\n'
    '${m.flags.map((f) => '${m.doc('flag.${f.name}', f.doc ?? 'The ${f.key} flag.')}'
        'const FeatureFlag<bool> ${f.name} = FeatureFlag<bool>(\n'
        "  key: '${f.key}',\n"
        '  defaultValue: ${f.defaultValue},\n'
        "  description: '${f.description.replaceAll("'", r"\'")}',\n"
        '  codec: BoolFlagCodec(),\n'
        ');').join('\n\n')}\n';

String _clock(DbModel m) => tpl(
  '''
<<d_doc>>final class <<Clock>> {
  const <<Clock>>(this.now);

  final DateTime Function() now;
}
''',
  {
    'd_doc': m.doc(
      'clock.doc',
      'The time countdowns count against. Injected: the app passes the\n'
          "backend's clock, and tests pass the fixtures' fixed clock. Provided by\n"
          'the flow (`provide:`), so it is not a root import.',
    ),
    'Clock': m.clock,
  },
);
