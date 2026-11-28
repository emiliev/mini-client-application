// The two bloc bodies of the search archetype: paged (a `PagingController`
// per search, server-side facets) and grouped (one request, a client-side
// filter). Their shared parts (history, the open guard, the generation
// guard) are written twice, as the exemplars do, so each reads whole.

import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const _openGuardDoc =
    'How long after opening a result a second open is ignored: the second tap\n'
    'of a double tap. By then the opened page covers the results.';

String pagedBloc(SrModel m, Map<String, String> v) {
  final names = m.facets.map((f) => 'the ${f.name}').join(' and ');
  final facetsBullet = m.text(
    'bloc.facets',
    '- **Facets:** $names ${m.facets.length == 1 ? 'is' : 'are'} sent to the backend. A change\n'
        '  searches the same query again from the first page (one request), and the\n'
        '  choice stays for the next query.',
  );
  final cases = [
    for (final f in m.facets)
      '      case ${f.caseClass}(:final ${f.name}):\n'
          '        if (${f.name} != _facets.${f.name}) {\n'
          '          _facets = _facets.${f.setter}(${f.name});\n'
          '          await _restart(emit);\n'
          '        }\n',
  ].join();
  return tpl(_paged, {
    ...v,
    'd_debounce': doc(
      m,
      'bloc.search_debounce',
      'How long typing must pause before a search goes out.',
    ),
    'd_page_size': doc(m, 'bloc.page_size', '${v['Items']} per request.'),
    'min_const': m.minLength > 1
        ? '${doc(m, 'bloc.min_length', 'The shortest query that is searched; a shorter one sends no request and\nshows the recent searches.')}'
              'const int minQueryLength = ${m.minLength};\n\n'
        : '',
    'search_case': m.minLength > 1
        ? '        if (query.runes.length < minQueryLength) {\n'
              '          _stop();\n'
              '          _showHistory(emit);\n'
              '        } else {\n'
              '          _saved = null;\n'
              '          await _start(query, emit);\n'
              '        }'
        : '        _saved = null;\n        await _start(query, emit);',
    'd_guard': doc(m, 'bloc.open_guard', _openGuardDoc),
    'd_class': doc(m, 'bloc.doc', _pagedClassDoc(facetsBullet)),
    'facet_cases': cases,
    'open_region': keepRegion(
      'search.open',
      '_navigator.${m.openCalls}(id);',
      indent: '        ',
    ),
  });
}

String groupedBloc(SrModel m, Map<String, String> v) {
  final open = [
    for (final h in m.hits)
      '  case ${h.hitClass}(:final id):\n'
          '    _navigator.${h.calls}(id);',
  ].join('\n');
  return tpl(_grouped, {
    ...v,
    'd_debounce': doc(
      m,
      'bloc.search_debounce',
      'How long typing must pause before a search goes out.',
    ),
    'd_min': doc(
      m,
      'bloc.min_length',
      'The shortest query the backend searches; a shorter one sends no request.',
    ),
    'd_guard': doc(m, 'bloc.open_guard', _openGuardDoc),
    'd_class': doc(m, 'bloc.doc', _groupedClassDoc),
    'open_region': keepRegion(
      'search.open',
      'switch (hit) {\n$open\n}',
      indent: '        ',
    ),
  });
}

String _pagedClassDoc(String facetsBullet) =>
    "The search page's bloc: turns the field's edits into one debounced\n"
    'request per pause, pages the matches as they are scrolled to, shows only\n'
    "the latest query's (and facets') answer, remembers the queries that found\n"
    'something, and hands a tapped result over to the app through the\n'
    'navigator, which only blocs call (plan 01 §4.1).\n'
    '\n'
    "- **Debounce:** `mc_paging`'s `DebouncedQuery` ([searchDebounce]) for what\n"
    "  is typed; a tapped recent search and the flow's initial query are\n"
    '  searched at once (`submit`). Any non-blank query is searched: this is a\n'
    '  prefix search, and one letter is a prefix.\n'
    '- **Paging:** each search owns one `PagingController` (its first page,\n'
    '  then a page each time the list scrolls near its end, retry, refresh).\n'
    '  The controller reports through `_PageChanged` events, because only a\n'
    '  handler emits.\n'
    '- **The latest search wins:** every search, facet change and clear starts\n'
    '  a new generation and disposes the previous controller, which drops its\n'
    '  answer on arrival; a page event of an older generation is dropped too.\n'
    '  So a slow answer for "sp" never replaces the one for "spi", and\n'
    '  clearing the field while a request is in flight shows the recent\n'
    '  searches.\n'
    '$facetsBullet\n'
    "- **Recent searches:** `mc_paging`'s `SearchHistory` on `mc_storage`\n"
    '  (most recent first, no duplicates, at most 10). A query that found\n'
    '  something is saved once; the list is read once when the bloc starts, so\n'
    '  it survives the flow. Each history change has a version, and only the\n'
    "  latest one's answer is shown. A save that fails reads the list again;\n"
    '  a clear that fails puts the list back and says so.\n'
    '- **One open per tap:** a second open within [openGuard] is ignored, so a\n'
    '  double tap hands the result over once.\n'
    '\n'
    'Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never\n'
    'Flutter, so every generator that reads it runs on analyzer summaries.';

const _groupedClassDoc =
    "The search page's bloc: turns the field's edits into one debounced\n"
    "request per pause, shows only the latest query's answer, remembers the\n"
    'queries that found something, and hands a tapped result over to the app\n'
    'through the navigator, which only blocs call (plan 01 §4.1).\n'
    '\n'
    "- **Debounce:** `mc_paging`'s `DebouncedQuery` ([searchDebounce]) for what\n"
    "  is typed; a tapped recent search and the flow's initial query are\n"
    '  searched at once (`submit`). A query shorter than [minQueryLength]\n'
    '  sends nothing, and one the backend finds too short shows the recent\n'
    '  searches as well, never a failure.\n'
    '- **The latest query wins:** every search, clear and too-short query\n'
    '  starts a new generation; an answer from an older generation is dropped,\n'
    '  so a slow answer for "sp" never replaces the one for "spi", and clearing\n'
    '  the field while a request is in flight shows the recent searches.\n'
    '- **Type filter:** client-side. One request answers both groups; a chip\n'
    '  changes which show and sends nothing.\n'
    "- **Recent searches:** `mc_paging`'s `SearchHistory` on `mc_storage`\n"
    '  (most recent first, no duplicates, at most 10). A search that found\n'
    '  something is saved; the list is read once when the bloc starts, so it\n'
    '  survives the flow. Each history change has a version, and only the\n'
    "  latest one's answer is shown. A save that fails reads the list again;\n"
    '  a clear that fails puts the list back and says so.\n'
    '- **One open per tap:** a second open within [openGuard] is ignored, so\n'
    '  a double tap hands the result over once.\n'
    '\n'
    'Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never\n'
    'Flutter, so every generator that reads it runs on analyzer summaries.';

const _paged = r'''
<<d_debounce>>const Duration searchDebounce = Duration(milliseconds: <<debounce>>);

<<min_const>><<d_page_size>>const int <<pageSizeConst>> = <<pageSize>>;

<<d_guard>>const Duration openGuard = Duration(milliseconds: <<guard>>);

<<d_class>>@injectable
final class <<Bloc>>
    extends McBloc<<<Event>>, <<State>>> {
  <<Bloc>>(
    this._repository,
    this._history,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(
        const <<State>>.idle(history: []),
        monitoring: monitoring,
      ) {
    on<<<Event>>>(_onEvent);
    add(const _LoadHistory());
    // A flow opened with a query (a link) searches it at once.
    if (_flow.state.initialQuery case final query?) {
      _query.submit(query);
    }
  }

  final <<Repository>> _repository;
  final SearchHistory _history;
  final FeatureFlowController<<<FlowState>>> _flow;
  final <<Navigator>> _navigator;

  late final DebouncedQuery _query = DebouncedQuery(
    onSearch: (query) => add(_Search(query)),
    onClear: () => add(const _Cleared()),
    delay: searchDebounce,
  );

  /// The newest search, facet change or clear. A page event shows only while
  /// its generation is still this one.
  int _generation = 0;

  /// The newest change of the recent searches (a load, an add, a clear).
  int _historyVersion = 0;

  /// The recent searches as last read or written.
  List<String> _recent = const [];

  /// The facets in force; they stay for the next query.
  <<Facets>> _facets = const <<Facets>>();

  /// The query on screen (searching, results, empty or failed); null while
  /// the recent searches show.
  String? _active;

  /// The query whose first results were saved to the history.
  String? _saved;

  /// The current search's pages; null while the recent searches show.
  PagingController<<<Entity>>>? _paging;

  /// Runs for [openGuard] after a result was opened.
  Timer? _openGuard;

  Future<void> _onEvent(
    <<Event>> event,
    Emitter<<<State>>> emit,
  ) async {
    switch (event) {
      case _QueryChanged(:final text):
        // Debounced: `_Search` or `_Cleared` comes back when typing pauses
        // (or at once for an empty field).
        _query.update(text);
      case _Submitted(:final text):
        _query.submit(text);
      case _Search(:final query):
<<search_case>>
      case _Cleared():
        _stop();
        _showHistory(emit);
<<facet_cases>>      case _PageChanged(:final generation, :final page):
        if (generation == _generation) {
          await _show(page, emit);
        }
      case _LoadMore():
        await _paging?.loadMore();
      case _Retry():
        await _paging?.retry();
      case _Refresh(:final done):
        try {
          await _paging?.refresh();
        } finally {
          done.complete();
        }
      case _Open(:final id):
        if (_openGuard?.isActive ?? false) {
          return;
        }
        _openGuard = Timer(openGuard, () {});
<<open_region>>
      case _LoadHistory():
        final version = _historyVersion;
        final loaded = await _history.load();
        if (version == _historyVersion) {
          _recent = loaded.getOrElse(() => const []);
          _refreshHistory(emit);
        }
      case _ClearHistory():
        final previous = _recent;
        final version = ++_historyVersion;
        _recent = const [];
        _refreshHistory(emit);
        final cleared = await _history.clear();
        final failed = cleared.fold((_) => false, (_) => true);
        if (failed && version == _historyVersion) {
          // Nothing was removed: the list is still what it was.
          _recent = previous;
          if (state is _Idle) {
            emit(
              <<State>>.idle(history: previous, clearFailed: true),
            );
          }
        }
    }
  }

  /// Searches [query] from its first page with the current facets. The
  /// previous search's controller is disposed, so its answer is dropped.
  Future<void> _start(
    String query,
    Emitter<<<State>>> emit,
  ) async {
    _paging?.dispose();
    final generation = ++_generation;
    final facets = _facets;
    _active = query;
    final paging = PagingController<<<Entity>>>(
      fetcher: (request) => _repository.fetchPage(
        <<Query>>(
          prefix: query,
          facets: facets,
          offset: request.offset,
          limit: request.limit,
        ),
      ),
      // The controller reports outside any handler; an event brings each
      // state back into the bloc, so only a handler emits.
      onState: (page) => add(_PageChanged(generation, page)),
      limit: <<pageSizeConst>>,
    );
    _paging = paging;
    emit(<<State>>.searching(query: query, facets: facets));
    await paging.loadFirst();
  }

  /// A facet changed: the query on screen, if any, starts over.
  Future<void> _restart(Emitter<<<State>>> emit) async {
    if (_active case final query?) {
      await _start(query, emit);
    }
  }

  /// Forgets the search on screen: no answer of it shows any more.
  void _stop() {
    _generation++;
    _paging?.dispose();
    _paging = null;
    _active = null;
    _saved = null;
  }

  /// What the paging controller's [page] looks like on screen. No items yet:
  /// a failure is the full-page error, a request in flight is still
  /// searching, and a settled one found nothing. With items, the list shows
  /// the page (its footer carries a later page's failure or spinner).
  Future<void> _show(
    PagedState<<<Entity>>> page,
    Emitter<<<State>>> emit,
  ) async {
    final query = _active!;
    final facets = _facets;
    switch (page) {
      case PagedState(items: [], failure: final error?):
        emit(
          <<State>>.failure(
            query: query,
            facets: facets,
            error: error,
          ),
        );
      case PagedState(items: [], hasReachedEnd: false):
        emit(<<State>>.searching(query: query, facets: facets));
      case PagedState(items: []):
        emit(<<State>>.empty(query: query, facets: facets));
      default:
        emit(
          <<State>>.results(
            query: query,
            page: page,
            facets: facets,
          ),
        );
        if (_saved != query) {
          _saved = query;
          await _remember(query, emit);
        }
    }
  }

  /// Saves [query] as the most recent search. Best effort: a failed write
  /// keeps the list as it was.
  Future<void> _remember(
    String query,
    Emitter<<<State>>> emit,
  ) async {
    final version = ++_historyVersion;
    final saved = await _history.add(query);
    // A failed save changed nothing on disk; read what is there, because
    // this save's version dropped the list the bloc read when it started.
    final list =
        saved.getOrNull() ?? (await _history.load()).getOrElse(() => const []);
    // Shown only if nothing changed the list since (a later save, a clear).
    if (version == _historyVersion) {
      _recent = list;
      _refreshHistory(emit);
    }
  }

  void _showHistory(Emitter<<<State>>> emit) =>
      emit(<<State>>.idle(history: _recent));

  /// Shows the current recent searches if they are on screen.
  void _refreshHistory(Emitter<<<State>>> emit) {
    if (state is _Idle) {
      _showHistory(emit);
    }
  }

  @override
  Future<void> close() {
    _query.dispose();
    _paging?.dispose();
    _openGuard?.cancel();
    return super.close();
  }
}''';

const _grouped = r'''
<<d_debounce>>const Duration searchDebounce = Duration(milliseconds: <<debounce>>);

<<d_min>>const int minQueryLength = <<min>>;

<<d_guard>>const Duration openGuard = Duration(milliseconds: <<guard>>);

<<d_class>>@injectable
final class <<Bloc>>
    extends McBloc<<<Event>>, <<State>>> {
  <<Bloc>>(
    this._repository,
    this._history,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(
        const <<State>>.idle(history: []),
        monitoring: monitoring,
      ) {
    on<<<Event>>>(_onEvent);
    add(const _LoadHistory());
    // A flow opened with a query (a link) searches it at once.
    if (_flow.state.initialQuery case final query?) {
      _query.submit(query);
    }
  }

  final <<Repository>> _repository;
  final SearchHistory _history;
  final FeatureFlowController<<<FlowState>>> _flow;
  final <<Navigator>> _navigator;

  late final DebouncedQuery _query = DebouncedQuery(
    onSearch: (query) => add(_Search(query)),
    onClear: () => add(const _Cleared()),
    delay: searchDebounce,
  );

  /// The newest search, clear or too-short query. A search's answer shows
  /// only while its generation is still this one.
  int _generation = 0;

  /// The newest change of the recent searches (a load, an add, a clear).
  int _historyVersion = 0;

  /// The recent searches as last read or written.
  List<String> _recent = const [];

  <<Filter>> _filter = <<filterDefault>>;

  /// Runs for [openGuard] after a result was opened.
  Timer? _openGuard;

  Future<void> _onEvent(
    <<Event>> event,
    Emitter<<<State>>> emit,
  ) async {
    switch (event) {
      case _QueryChanged(:final text):
        // Debounced: `_Search` or `_Cleared` comes back when typing pauses
        // (or at once for an empty field).
        _query.update(text);
      case _Submitted(:final text):
        _query.submit(text);
      case _Search(:final query):
        await _search(query, emit);
      case _Cleared():
        _generation++;
        _showHistory(emit);
      case _Retry():
        // One Retry at a time: the first one leaves the failure state.
        if (state case _Failure(:final query)) {
          await _search(query, emit);
        }
      case _FilterChanged(:final filter):
        _filter = filter;
        if (state case final _Results shown) {
          emit(shown.copyWith(filter: filter));
        }
      case _Open(:final hit):
        if (_openGuard?.isActive ?? false) {
          return;
        }
        _openGuard = Timer(openGuard, () {});
<<open_region>>
      case _LoadHistory():
        final version = _historyVersion;
        final loaded = await _history.load();
        if (version == _historyVersion) {
          _recent = loaded.getOrElse(() => const []);
          _refreshHistory(emit);
        }
      case _ClearHistory():
        final previous = _recent;
        final version = ++_historyVersion;
        _recent = const [];
        _refreshHistory(emit);
        final cleared = await _history.clear();
        final failed = cleared.fold((_) => false, (_) => true);
        if (failed && version == _historyVersion) {
          // Nothing was removed: the list is still what it was.
          _recent = previous;
          if (state is _Idle) {
            emit(
              <<State>>.idle(history: previous, clearFailed: true),
            );
          }
        }
    }
  }

  Future<void> _search(
    String query,
    Emitter<<<State>>> emit,
  ) async {
    final generation = ++_generation;
    if (query.runes.length < minQueryLength) {
      _showHistory(emit);
      return;
    }
    emit(<<State>>.searching(query: query));
    final result = await _repository.search(query);
    if (generation != _generation) {
      // A newer search, a clear or a too-short query came first.
      return;
    }
    final found = result.fold(
      (results) {
        if (results == null) {
          // The backend counts the query as too short (after folding).
          _showHistory(emit);
          return false;
        }
        emit(
          results.isEmpty
              ? <<State>>.empty(query: query)
              : <<State>>.results(
                  query: query,
                  results: results,
                  filter: _filter,
                ),
        );
        return !results.isEmpty;
      },
      (error) {
        emit(<<State>>.failure(query: query, error: error));
        return false;
      },
    );
    if (found) {
      await _remember(query, emit);
    }
  }

  /// Saves [query] as the most recent search. Best effort: a failed write
  /// keeps the list as it was.
  Future<void> _remember(
    String query,
    Emitter<<<State>>> emit,
  ) async {
    final version = ++_historyVersion;
    final saved = await _history.add(query);
    // A failed save changed nothing on disk; read what is there, because
    // this save's version dropped the list the bloc read when it started.
    final list =
        saved.getOrNull() ?? (await _history.load()).getOrElse(() => const []);
    // Shown only if nothing changed the list since (a later save, a clear).
    if (version == _historyVersion) {
      _recent = list;
      _refreshHistory(emit);
    }
  }

  void _showHistory(Emitter<<<State>>> emit) =>
      emit(<<State>>.idle(history: _recent));

  /// Shows the current recent searches if they are on screen.
  void _refreshHistory(Emitter<<<State>>> emit) {
    if (state is _Idle) {
      _showHistory(emit);
    }
  }

  @override
  Future<void> close() {
    _query.dispose();
    _openGuard?.cancel();
    return super.close();
  }
}''';
