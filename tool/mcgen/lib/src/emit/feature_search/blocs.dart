// The search bloc, its events and its states (Tide 5.8: hand-style sealed
// events with private cases, freezed `sealed` states with private cases,
// monitoring in `McBloc`).
//
// The bloc owns the cross-cutting search behaviour: `DebouncedQuery` for the
// field, `SearchHistory` for the recent searches, the generation guard so
// only the latest query's answer shows, the open guard, and (paged) one
// `PagingController` per search. Everything domain-specific it takes from
// the module's own files (`options.files`, `options.names`).

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_search/bloc_templates.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _bloc = 'lib/src/presentation/bloc';

void emitBlocs(EmitContext ctx, SrModel m) {
  final base = '$_bloc/${m.module}';
  ctx.library(
    DartLibrary(
      '${base}_event.dart',
      partOf: '${m.module}_bloc.dart',
      imports: [if (m.paged) 'dart:async'],
      decls: [RawDecl(Code(_event(m)))],
    ),
  );
  ctx.library(
    DartLibrary(
      '${base}_state.dart',
      partOf: '${m.module}_bloc.dart',
      decls: [RawDecl(Code(_state(m)))],
    ),
  );
  ctx.library(
    DartLibrary(
      '${base}_bloc.dart',
      imports: [
        'dart:async',
        'package:bloc/bloc.dart',
        m.uri('domain/repository/${m.module}_repository.dart'),
        m.uri('flow/${m.module}_flow_state.dart'),
        m.uri('navigator/${m.module}_navigator.dart'),
        'package:freezed_annotation/freezed_annotation.dart',
        'package:injectable/injectable.dart',
        'package:mc_api_errors/mc_api_errors.dart',
        'package:mc_bloc_kit/mc_bloc_kit.dart',
        'package:mc_monitoring/mc_monitoring.dart',
        'package:mc_paging/mc_paging.dart',
        if (m.paged) ...[
          m.uri('domain/model/${m.file('entity')}'),
          m.uri('domain/model/${m.file('facets')}'),
          m.uri(
            'domain/model/${m.ids.firstWhere((i) => i.name == m.openId).file}',
          ),
        ] else
          m.uri('domain/model/${m.file('results')}'),
      ],
      parts: [
        '${m.module}_bloc.freezed.dart',
        '${m.module}_event.dart',
        '${m.module}_state.dart',
      ],
      decls: [
        RawDecl(
          Code(m.paged ? pagedBloc(m, _vars(m)) : groupedBloc(m, _vars(m))),
        ),
      ],
    ),
  );
}

Map<String, String> _vars(SrModel m) => {
  'module': m.module,
  'Pascal': m.pascal,
  'Event': m.event,
  'State': m.state,
  'Bloc': m.bloc,
  'Navigator': m.navigator,
  'FlowState': m.flowState,
  'Repository': m.repository,
  'debounce': '${m.debounceMs}',
  'guard': '${m.openGuardMs}',
  'min': '${m.minLength}',
  'Items': pascalCase(m.items),
  if (m.paged) ...{
    'Entity': m.entity,
    'Facets': m.name('facets'),
    'Query': m.name('query'),
    'pageSizeConst': m.pageSizeConst,
    'pageSize': '${m.pageSize}',
    'open': m.openCalls,
    'Id': m.openId,
  } else ...{
    'Results': m.name('results'),
    'Hit': m.name('hit'),
    'Filter': m.name('filter'),
    'filterDefault': m.filterDefault,
  },
};

/// [blocks] joined by one blank line.
String _join(List<String> blocks) => '${blocks.join('\n\n')}\n';

// --- events -------------------------------------------------------------------

/// A sealed event's case class: [fields] are (type, name).
String _case(
  String name,
  String superclass,
  List<(String, String)> fields, [
  String? docText,
]) {
  final ctor = fields.map((f) => 'this.${f.$2}').join(', ');
  return '${docLines(docText)}final class $name extends $superclass {\n'
      '  const $name($ctor);\n'
      '${fields.isEmpty ? '' : '\n${[for (final f in fields) '  final ${f.$1} ${f.$2};'].join('\n')}\n'}'
      '}';
}

String _event(SrModel m) {
  final v = _vars(m);
  final e = m.event;
  // (slot, default doc, factory signature, case class, fields)
  final cases = <(String, String, String, String, List<(String, String)>)>[
    (
      'event.query_changed',
      "The field's text changed (every edit, the clear button included).",
      'queryChanged(String text)',
      '_QueryChanged',
      [('String', 'text')],
    ),
    (
      'event.submitted',
      "A query to search at once: a tapped recent search, or the keyboard's\nSearch key.",
      'submitted(String text)',
      '_Submitted',
      [('String', 'text')],
    ),
    if (m.paged) ...[
      for (final f in m.facets)
        (
          'event.${snakeCase(f.event)}',
          f.doc ?? 'A ${f.name} was chosen.',
          '${f.event}(${f.type} ${f.name})',
          f.caseClass,
          [(f.type, f.name)],
        ),
      (
        'event.load_more',
        'The results scrolled past their load-more threshold.',
        'loadMore()',
        '_LoadMore',
        <(String, String)>[],
      ),
      (
        'event.retry',
        'Retry after a failed request (the first page or a later one).',
        'retry()',
        '_Retry',
        <(String, String)>[],
      ),
      (
        'event.refresh',
        'Pull to refresh: reloads the first page and keeps the results meanwhile.\n'
            '[done] completes when the reload settled, so the refresh control closes.',
        'refresh(Completer<void> done)',
        '_Refresh',
        [('Completer<void>', 'done')],
      ),
    ] else ...[
      (
        'event.filter_changed',
        'A type chip was chosen.',
        'filterChanged(${v['Filter']} filter)',
        '_FilterChanged',
        [(v['Filter']!, 'filter')],
      ),
      (
        'event.retry',
        'Retry after a failed search: the same query again.',
        'retry()',
        '_Retry',
        <(String, String)>[],
      ),
    ],
    (
      'event.clear_history',
      '"Clear" above the recent searches.',
      'clearHistory()',
      '_ClearHistory',
      <(String, String)>[],
    ),
    if (m.paged)
      (
        'event.open',
        'A result was tapped.',
        'open(${v['Id']} id)',
        '_Open',
        [(v['Id']!, 'id')],
      )
    else
      (
        'event.open',
        'A result was tapped.',
        'open(${v['Hit']} hit)',
        '_Open',
        [(v['Hit']!, 'hit')],
      ),
  ];
  final factories = [
    for (final (slot, defaultDoc, sig, cls, _) in cases)
      '${doc(m, slot, defaultDoc, indent: '  ')}'
          '  const factory $e.$sig =\n      $cls;',
  ];
  return _join([
    '${doc(m, 'event.doc', 'What the search page asks for. Hand-written sealed events with private\n'
            'cases (Tide), so a page can only create them through the factories; the\n'
            "bloc's own events (the debounced search, the clear, the history load${m.paged ? ', a\npage of results) have no factory.' : ')\nhave no factory.'}")}'
        'sealed class $e {\n  const $e();\n\n${factories.join('\n\n')}\n}',
    for (final (_, _, _, cls, fields) in cases) _case(cls, e, fields),
    _case('_Search', e, [
      ('String', 'query'),
    ], 'Typing paused on [query] (from `DebouncedQuery`).'),
    _case(
      '_Cleared',
      e,
      const [],
      'The field became empty after a search fired (from `DebouncedQuery`).',
    ),
    _case(
      '_LoadHistory',
      e,
      const [],
      'Reads the saved recent searches, once, when the bloc starts.',
    ),
    if (m.paged)
      _case('_PageChanged', e, [
        ('int', 'generation'),
        ('PagedState<${m.entity}>', 'page'),
      ], 'The paging controller of search [generation] produced a new state.'),
  ]);
}

// --- states -------------------------------------------------------------------

String _state(SrModel m) {
  final s = m.state;
  final v = _vars(m);
  final facets = m.paged ? ', required ${v['Facets']} facets,' : '';
  String factory(String slot, String defaultDoc, String text) =>
      '${doc(m, slot, defaultDoc, indent: '  ')}$text';
  return _join([
    '${doc(m, 'state.doc', "Tide's state shape: private cases read with `state.when` (R16); freezed 4\nadds only `sealed`.")}'
        '@freezed\n'
        'sealed class $s with _\$$s {\n'
        '${[
          factory(
            'state.idle',
            m.paged ? 'Nothing is searched: the field is empty. The recent searches show, most\n'
                      'recent first. [clearFailed] when the last Clear could not remove them\n'
                      '(they still show).' : 'Nothing is searched: the field is empty, or its text is too short. The\n'
                      'recent searches show, most recent first. [clearFailed] when the last\n'
                      'Clear could not remove them (they still show).',
            '  const factory $s.idle({\n'
                '    required List<String> history,\n'
                '    @Default(false) bool clearFailed,\n'
                '  }) = _Idle;',
          ),
          factory(
            'state.searching',
            m.paged ? "[query]'s first page is on its way." : "[query]'s request is in flight.",
            '  const factory $s.searching({required String query$facets}) = _Searching;',
          ),
          factory(
            'state.results',
            m.paged ? '[query] found ${m.items}: the pages loaded so far (a later page may be\n'
                      'loading or failing: [PagedState.isLoadingMore], [PagedState.failure]).' : '[query] found something. [filter] picks the groups that show; the\n'
                      'results always hold both.',
            m.paged ? '  const factory $s.results({\n'
                      '    required String query,\n'
                      '    required PagedState<${v['Entity']}> page,\n'
                      '    required ${v['Facets']} facets,\n'
                      '  }) = _Results;' : '  const factory $s.results({\n'
                      '    required String query,\n'
                      '    required ${v['Results']} results,\n'
                      '    required ${v['Filter']} filter,\n'
                      '  }) = _Results;',
          ),
          factory(
            'state.empty',
            m.paged ? '[query] with [facets] found nothing. Not a failure: nothing to retry.' : '[query] found nothing in any group. Not a failure: nothing to retry.',
            '  const factory $s.empty({required String query$facets}) = _Empty;',
          ),
          factory(
            'state.failure',
            m.paged ? "[query]'s first page failed; Retry asks for it again. `McBloc` reports\n"
                      'it to monitoring (D-16).' : "[query]'s request failed; Retry searches it again. `McBloc` reports it\n"
                      'to monitoring (D-16).',
            '  @Implements<McFailureState>()\n'
                '  const factory $s.failure({\n'
                '    required String query,\n'
                '${m.paged ? '    required ${v['Facets']} facets,\n' : ''}'
                '    required ApiFailure error,\n'
                '    StackTrace? stackTrace,\n'
                '  }) = _Failure;',
          ),
        ].join('\n\n')}\n}',
  ]);
}
