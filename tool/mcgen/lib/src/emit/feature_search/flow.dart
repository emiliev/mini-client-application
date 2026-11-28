// The search flow layer: the barrel, DI, the root-import list, the navigator
// contract, the flow state, the flow and the screen name (Tide nav 3.3, 3.4).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _widgets = 'package:flutter/widgets.dart';

/// Word-wraps [text] to [width] columns (greedy), keeping blank lines.
String wrap(String text, int width) => text
    .split('\n')
    .map((para) {
      if (para.isEmpty) return para;
      final lines = <String>[];
      var line = '';
      for (final w in para.split(' ')) {
        if (line.isEmpty) {
          line = w;
        } else if (line.length + 1 + w.length <= width) {
          line = '$line $w';
        } else {
          lines.add(line);
          line = w;
        }
      }
      lines.add(line);
      return lines.join('\n');
    })
    .join('\n');

void emitFlow(EmitContext ctx, SrModel m) {
  final nav = m.spec.navigator!;
  ctx.library(
    DartLibrary(
      'lib/${m.module}.dart',
      preamble: commentLines(
        m.text(
          'barrel.preamble',
          'The public surface (R4, checked by mc_arch_check and the architecture\n'
              "test): the flow, its navigator and the navigator's argument types. No\n"
              "`library;` directive (Tide's `unnecessary_library_directive`).",
        ),
      ),
      exports: [
        Exports([m.flow, m.navigator, for (final id in m.ids) id.name]),
      ],
    ),
  );
  for (final id in m.ids) {
    ctx.library(
      DartLibrary(
        'lib/src/domain/model/${id.file}',
        decls: [
          ExtensionTypeDecl(
            id.name,
            Code('${id.type} value'),
            doc: id.doc ?? "An id in this feature's own vocabulary.",
          ),
        ],
      ),
    );
  }
  if (m.screenFile case final file?) {
    ctx.library(
      DartLibrary(
        'lib/src/domain/model/$file',
        decls: [
          RawDecl(
            Code("const String ${m.screenConst} = '${m.module}';"),
            name: m.screenConst,
            doc: m.text(
              'analytics.doc',
              "The screen name of the flow's one page: its `McFlowPage` name, which\n"
                  '`AnalyticsFlowObserver` tracks. It equals the app route\'s name, so it is\n'
                  'not tracked twice (ADR-0012).',
            ),
          ),
        ],
      ),
    );
  }

  ctx.dartBrick(
    'feature_search_di',
    {'pascal': m.pascal},
    imports: {
      'lib/src/di/di_initializer.dart': [
        'dart:async',
        'package:${m.module}/src/di/di_initializer.config.dart',
      ],
    },
    defines: {
      'lib/src/di/di_initializer.dart': [m.diInitializer],
    },
  );

  final analytics = m.screenFile != null;
  ctx.library(
    DartLibrary(
      'lib/src/di/di_module.dart',
      imports: [
        'package:injectable/injectable.dart',
        'package:mc_paging/mc_paging.dart',
        'package:mc_storage/mc_storage.dart',
      ],
      decls: [
        RawDecl(
          Code(
            tpl(_diModule, {
              'Module': m.diModule,
              'key': m.historyKey,
              'cap': '${m.historyCap}',
              'd_key': doc(
                m,
                'di.key',
                'The `FileStore` key of the recent searches. Every flow instance reads and\n'
                    'writes the same key, so the list survives the flow (and the app).',
              ),
            }),
          ),
          name: m.diModule,
        ),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      'lib/src/di/flow_scope.dart',
      imports: [
        'package:dio/dio.dart',
        'package:mc_di/mc_di.dart',
        'package:mc_monitoring/mc_monitoring.dart',
        'package:mc_storage/mc_storage.dart',
      ],
      decls: [
        RawDecl(
          Code(
            'const List<RootImport<Object>> ${m.rootImports} = [\n'
            '${analytics ? '  RootImport<AnalyticsTracker>(),\n' : ''}'
            '  RootImport<Dio>(),\n'
            '  RootImport<FileStore>(),\n'
            '  RootImport<Monitoring>(),\n'
            '];',
          ),
          name: m.rootImports,
          doc: m.text(
            'flow_scope.doc',
            "The root services this flow's container forwards (R17): the parameter\n"
                'types of every injectable constructor, `@factoryMethod` and module member\n'
                'in the package, ${analytics ? 'plus the screen tracker the flow\'s observer resolves,\n'
                          'minus what the package registers itself and what the flow provides\n'
                          '(`FeatureFlowController`, the navigator).' : 'minus what the package registers itself and what the flow\n'
                          'provides (`FeatureFlowController`, the navigator).'}\n'
                '\n'
                'HAND-WRITTEN FOR NOW. Plan 01 §4.5 has `mcgen wire` derive this file from\n'
                'the same analyzer input injectable reads, and `mcgen check` fail on drift\n'
                '(Phase D). Until then `test/flow_scope_test.dart` opens the flow over the\n'
                'production-shaped test root and resolves every registration, so a missing\n'
                'import fails a test, not the app.',
          ),
        ),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      'lib/src/navigator/${m.module}_navigator.dart',
      imports: [
        for (final id in m.ids)
          if (nav.outbound.any((o) => o.args.contains(id.name)))
            m.uri('domain/model/${id.file}'),
      ],
      decls: [
        ClassDecl(
          m.navigator,
          modifiers: 'abstract interface',
          doc: nav.doc,
          members: [
            for (final o in nav.outbound)
              RawMember(
                Code(
                  'void ${o.name}(${[for (final a in o.args) '$a id'].join(', ')});',
                ),
                doc: m.text(
                  'navigator.${o.name}',
                  'Leaves the feature: ${o.name}.',
                ),
              ),
          ],
        ),
      ],
    ),
  );
  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.module}_flow_state.dart',
      parts: ['${m.module}_flow_state.freezed.dart'],
      imports: ['package:freezed_annotation/freezed_annotation.dart'],
      decls: [
        RawDecl(
          Code(
            tpl(_flowState, {
              'FlowState': m.flowState,
              'd_class': doc(
                m,
                'flow_state.doc',
                'What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,\n'
                    'so the bloc that reads it stays Flutter-free (R15).',
              ),
              'd_query': doc(
                m,
                'flow_state.initial_query',
                'The query the flow opened with: the field starts with it and it is\n'
                    'searched at once. Null (the flow treats a blank query as none) opens on\n'
                    'the recent searches.',
                indent: '    ',
              ),
            }),
          ),
          name: m.flowState,
        ),
      ],
    ),
  );
  final screen = analytics ? m.screenConst! : "'${m.pageName}'";
  ctx.library(
    DartLibrary(
      'lib/src/flow/${m.module}_flow.dart',
      imports: [
        _widgets,
        m.uri('di/di_initializer.dart'),
        m.uri('di/flow_scope.dart'),
        m.uri('flow/${m.module}_flow_state.dart'),
        m.uri('l10n/${m.module}_l10n.dart'),
        m.uri('navigator/${m.module}_navigator.dart'),
        m.uri('presentation/page/${m.module}_page.dart'),
        'package:mc_feature_flow/mc_feature_flow.dart',
        if (analytics) ...[
          m.uri('domain/model/${m.screenFile}'),
          'package:mc_analytics/mc_analytics.dart',
          'package:mc_monitoring/mc_monitoring.dart',
        ],
      ],
      decls: [
        RawDecl(
          Code(
            tpl(_flow, {
              'Flow': m.flow,
              'FlowState': m.flowState,
              'Navigator': m.navigator,
              'Page': m.page,
              'DIInitializer': m.diInitializer,
              'rootImports': m.rootImports,
              'L10n': m.l10nClass,
              'screen': screen,
              'd_class': _flowDoc(m, analytics),
              'd_query': doc(
                m,
                'flow.query_doc',
                '[initialQuery], with a blank one as none.',
                indent: '  ',
              ),
              'query_getter': m.trimQuery
                  ? '    final query = initialQuery?.trim();\n'
                        '    return query == null || query.isEmpty ? null : query;'
                  : '    final query = initialQuery;\n'
                        '    return query == null || query.trim().isEmpty ? null : query;',
              'observers': analytics
                  ? '    // The flow\'s pages are screens: resolved inside the flow, without a\n'
                        '    // dependency on the host route (F-0056 section 4).\n'
                        '    observers: [\n'
                        '      AnalyticsFlowObserver(\n'
                        '        (context) => context.di<AnalyticsTracker>(),\n'
                        '        host: (context) => FlowScope.read(context).outerRoute,\n'
                        '      ),\n'
                        '    ],\n'
                  : '',
            }),
          ),
          name: m.flow,
        ),
      ],
    ),
  );
}

String _flowDoc(SrModel m, bool analytics) {
  final intro = m.text(
    'flow.intro',
    "The feature's only entry point (R4): search ${m.items}, whose results leave\n"
        'the feature through [navigator].\n'
        '\n'
        'The app builds it from a route with the navigator implementation from its\n'
        'wiring; tests pass a mock. It can start from a query alone (plan 01 §4.4).',
  );
  final screen = analytics
      ? '\n\n${m.text('flow.screen', wrap('Its one page is the screen `${m.module}`, tracked from inside the flow by `AnalyticsFlowObserver` (ADR-0012).', 76))}'
      : '';
  return docLines(
    '$intro$screen\n'
    '\n'
    'Immutable after creation: the flow reads [navigator] and [initialQuery]\n'
    'once, when its scope opens (`provide:` runs once per flow instance). A\n'
    'rebuild with a different navigator keeps the first one; a different\n'
    '[initialQuery] builds a new flow (its `FeatureFlow` is keyed by it), with\n'
    'a fresh scope, state and page.',
  );
}

const _diModule = r'''
<<d_key>>const String searchHistoryStoreKey = '<<key>>';

/// How many recent searches are kept.
const int searchHistoryCap = <<cap>>;

/// Kit types this feature registers itself (plan 01 §3.3, `di_module.dart`):
/// `mc_paging`'s `SearchHistory` is not injectable-annotated.
@module
abstract class <<Module>> {
  /// One history per flow scope, so its adds and clears are serialised
  /// (`SearchHistory`'s queue is per instance). Two flows open at once on the
  /// same key read and write independently, which the kit accepts.
  @lazySingleton
  SearchHistory searchHistory(FileStore store) =>
      SearchHistory(store, cap: searchHistoryCap, key: searchHistoryStoreKey);
}''';

const _flowState = r'''
<<d_class>>@freezed
abstract class <<FlowState>> with _$<<FlowState>> {
  const factory <<FlowState>>({
<<d_query>>    String? initialQuery,
  }) = _<<FlowState>>;
}''';

const _flow = r'''
<<d_class>>class <<Flow>> extends StatelessWidget {
  const <<Flow>>({
    required this.navigator,
    this.initialQuery,
    super.key,
  });

  final <<Navigator>> navigator;

  /// Starts the search with this text in the field, searched at once. Null
  /// or blank opens on the recent searches, with the keyboard up.
  final String? initialQuery;

<<d_query>>  String? get _query {
<<query_getter>>
  }

  @override
  Widget build(BuildContext context) => FeatureFlow<<<FlowState>>>(
    key: ValueKey(_query),
    flowInitializer: const <<DIInitializer>>(),
    rootImports: <<rootImports>>,
    provide: (scope) =>
        scope.registerSingleton<<<Navigator>>>(navigator),
    localizationsDelegates: const [<<L10n>>.delegate],
<<observers>>    state: <<FlowState>>(initialQuery: _query),
    onGeneratePages: (state) => [
      McFlowPage(
        name: <<screen>>,
        arguments: state.initialQuery,
        child: <<Page>>(initialQuery: state.initialQuery),
      ),
    ],
  );
}''';
