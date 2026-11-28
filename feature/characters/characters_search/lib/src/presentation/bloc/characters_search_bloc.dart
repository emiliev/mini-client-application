import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:characters_search/src/domain/model/character.dart';
import 'package:characters_search/src/domain/model/character_facets.dart';
import 'package:characters_search/src/domain/model/character_id.dart';
import 'package:characters_search/src/domain/repository/characters_search_repository.dart';
import 'package:characters_search/src/flow/characters_search_flow_state.dart';
import 'package:characters_search/src/navigator/characters_search_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';

part 'characters_search_bloc.freezed.dart';
part 'characters_search_event.dart';
part 'characters_search_state.dart';

/// How long typing must pause before a search goes out (T-0071).
const Duration searchDebounce = Duration(milliseconds: 300);

/// Characters per request.
const int charactersSearchPageSize = 30;

/// How long after opening a result a second open is ignored: the second tap
/// of a double tap. By then the opened page covers the results.
const Duration openGuard = Duration(milliseconds: 500);

/// The search page's bloc: turns the field's edits into one debounced
/// request per pause, pages the matches as they are scrolled to, shows only
/// the latest query's (and facets') answer, remembers the queries that found
/// something, and hands a tapped result over to the app through the
/// navigator, which only blocs call (plan 01 §4.1).
///
/// - **Debounce:** `mc_paging`'s `DebouncedQuery` ([searchDebounce]) for what
///   is typed; a tapped recent search and the flow's initial query are
///   searched at once (`submit`). Any non-blank query is searched: this is a
///   prefix search, and one letter is a prefix.
/// - **Paging:** each search owns one `PagingController` (its first page,
///   then a page each time the list scrolls near its end, retry, refresh).
///   The controller reports through `_PageChanged` events, because only a
///   handler emits.
/// - **The latest search wins:** every search, facet change and clear starts
///   a new generation and disposes the previous controller, which drops its
///   answer on arrival; a page event of an older generation is dropped too.
///   So a slow answer for "sp" never replaces the one for "spi", and
///   clearing the field while a request is in flight shows the recent
///   searches.
/// - **Facets:** the sort order and the team are sent to the backend. A
///   change searches the same query again from the first page (one
///   request), and the choice stays for the next query.
/// - **Recent searches:** `mc_paging`'s `SearchHistory` on `mc_storage`
///   (most recent first, no duplicates, at most 10). A query that found
///   something is saved once; the list is read once when the bloc starts, so
///   it survives the flow. Each history change has a version, and only the
///   latest one's answer is shown. A save that fails reads the list again;
///   a clear that fails puts the list back and says so.
/// - **One open per tap:** a second open within [openGuard] is ignored, so a
///   double tap hands the result over once.
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@injectable
final class CharactersSearchBloc
    extends McBloc<CharactersSearchEvent, CharactersSearchState> {
  CharactersSearchBloc(
    this._repository,
    this._history,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(
        const CharactersSearchState.idle(history: []),
        monitoring: monitoring,
      ) {
    on<CharactersSearchEvent>(_onEvent);
    add(const _LoadHistory());
    // A flow opened with a query (a link) searches it at once.
    if (_flow.state.initialQuery case final query?) {
      _query.submit(query);
    }
  }

  final CharactersSearchRepository _repository;
  final SearchHistory _history;
  final FeatureFlowController<CharactersSearchFlowState> _flow;
  final CharactersSearchNavigator _navigator;

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
  CharacterFacets _facets = const CharacterFacets();

  /// The query on screen (searching, results, empty or failed); null while
  /// the recent searches show.
  String? _active;

  /// The query whose first results were saved to the history.
  String? _saved;

  /// The current search's pages; null while the recent searches show.
  PagingController<Character>? _paging;

  /// Runs for [openGuard] after a result was opened.
  Timer? _openGuard;

  Future<void> _onEvent(
    CharactersSearchEvent event,
    Emitter<CharactersSearchState> emit,
  ) async {
    switch (event) {
      case _QueryChanged(:final text):
        // Debounced: `_Search` or `_Cleared` comes back when typing pauses
        // (or at once for an empty field).
        _query.update(text);
      case _Submitted(:final text):
        _query.submit(text);
      case _Search(:final query):
        _saved = null;
        await _start(query, emit);
      case _Cleared():
        _stop();
        _showHistory(emit);
      case _SortChanged(:final sort):
        if (sort != _facets.sort) {
          _facets = _facets.withSort(sort);
          await _restart(emit);
        }
      case _TeamChanged(:final team):
        if (team != _facets.team) {
          _facets = _facets.withTeam(team);
          await _restart(emit);
        }
      case _PageChanged(:final generation, :final page):
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
        // mcgen:keep search.open
        _navigator.openCharacter(id);
      // mcgen:end search.open
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
              CharactersSearchState.idle(history: previous, clearFailed: true),
            );
          }
        }
    }
  }

  /// Searches [query] from its first page with the current facets. The
  /// previous search's controller is disposed, so its answer is dropped.
  Future<void> _start(
    String query,
    Emitter<CharactersSearchState> emit,
  ) async {
    _paging?.dispose();
    final generation = ++_generation;
    final facets = _facets;
    _active = query;
    final paging = PagingController<Character>(
      fetcher: (request) => _repository.fetchPage(
        CharactersSearchQuery(
          prefix: query,
          facets: facets,
          offset: request.offset,
          limit: request.limit,
        ),
      ),
      // The controller reports outside any handler; an event brings each
      // state back into the bloc, so only a handler emits.
      onState: (page) => add(_PageChanged(generation, page)),
      limit: charactersSearchPageSize,
    );
    _paging = paging;
    emit(CharactersSearchState.searching(query: query, facets: facets));
    await paging.loadFirst();
  }

  /// A facet changed: the query on screen, if any, starts over.
  Future<void> _restart(Emitter<CharactersSearchState> emit) async {
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
    PagedState<Character> page,
    Emitter<CharactersSearchState> emit,
  ) async {
    final query = _active!;
    final facets = _facets;
    switch (page) {
      case PagedState(items: [], failure: final error?):
        emit(
          CharactersSearchState.failure(
            query: query,
            facets: facets,
            error: error,
          ),
        );
      case PagedState(items: [], hasReachedEnd: false):
        emit(CharactersSearchState.searching(query: query, facets: facets));
      case PagedState(items: []):
        emit(CharactersSearchState.empty(query: query, facets: facets));
      default:
        emit(
          CharactersSearchState.results(
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
    Emitter<CharactersSearchState> emit,
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

  void _showHistory(Emitter<CharactersSearchState> emit) =>
      emit(CharactersSearchState.idle(history: _recent));

  /// Shows the current recent searches if they are on screen.
  void _refreshHistory(Emitter<CharactersSearchState> emit) {
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
}
