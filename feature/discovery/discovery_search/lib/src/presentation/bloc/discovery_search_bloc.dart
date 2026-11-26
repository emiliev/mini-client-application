import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:discovery_search/src/domain/repository/discovery_search_repository.dart';
import 'package:discovery_search/src/flow/discovery_search_flow_state.dart';
import 'package:discovery_search/src/navigator/discovery_search_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';

part 'discovery_search_bloc.freezed.dart';
part 'discovery_search_event.dart';
part 'discovery_search_state.dart';

/// How long typing must pause before a search goes out (P1-19).
const Duration searchDebounce = Duration(milliseconds: 300);

/// The shortest query the backend searches (`mc_fixtures_discovery`
/// CONTRACT.md); a shorter one sends no request. The backend counts after
/// folding accents away, so it may still answer "too short" for a query the
/// client counts as long enough; that answer shows the recent searches too.
const int minQueryLength = 2;

/// How long after opening a result a second open is ignored: the second tap
/// of a double tap. By then the opened page covers the results.
const Duration openGuard = Duration(milliseconds: 500);

/// The search page's bloc: turns the field's edits into one debounced
/// request per pause, shows only the latest query's answer, remembers the
/// queries that found something, and hands a tapped result over to the app
/// through the navigator, which only blocs call (plan 01 §4.1).
///
/// - **Debounce:** `mc_paging`'s `DebouncedQuery` ([searchDebounce]) for what
///   is typed; a tapped recent search and the flow's initial query are
///   searched at once (`submit`). A query shorter than [minQueryLength]
///   sends nothing, and one the backend finds too short shows the recent
///   searches as well, never a failure.
/// - **The latest query wins:** every search, clear and too-short query
///   starts a new generation; an answer from an older generation is dropped,
///   so a slow answer for "sp" never replaces the one for "spi", and clearing
///   the field while a request is in flight shows the recent searches.
/// - **Type filter:** client-side. One request answers both groups; a chip
///   changes which show and sends nothing.
/// - **Recent searches:** `mc_paging`'s `SearchHistory` on `mc_storage`
///   (most recent first, no duplicates, at most 10). A search that found
///   something is saved; the list is read once when the bloc starts, so it
///   survives the flow. Each history change has a version, and only the
///   latest one's answer is shown. A save that fails reads the list again;
///   a clear that fails puts the list back and says so.
/// - **One open per tap:** a second open within [openGuard] is ignored, so
///   a double tap hands the result over once.
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@injectable
final class DiscoverySearchBloc
    extends McBloc<DiscoverySearchEvent, DiscoverySearchState> {
  DiscoverySearchBloc(
    this._repository,
    this._history,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(
        const DiscoverySearchState.idle(history: []),
        monitoring: monitoring,
      ) {
    on<DiscoverySearchEvent>(_onEvent);
    add(const _LoadHistory());
    // A flow opened with a query (a link) searches it at once.
    if (_flow.state.initialQuery case final query?) {
      _query.submit(query);
    }
  }

  final DiscoverySearchRepository _repository;
  final SearchHistory _history;
  final FeatureFlowController<DiscoverySearchFlowState> _flow;
  final DiscoverySearchNavigator _navigator;

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

  SearchFilter _filter = SearchFilter.all;

  /// Runs for [openGuard] after a result was opened.
  Timer? _openGuard;

  Future<void> _onEvent(
    DiscoverySearchEvent event,
    Emitter<DiscoverySearchState> emit,
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
        switch (hit) {
          case CharacterHit(:final id):
            _navigator.openCharacter(id);
          case ComicHit(:final id):
            _navigator.openComic(id);
        }
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
              DiscoverySearchState.idle(history: previous, clearFailed: true),
            );
          }
        }
    }
  }

  Future<void> _search(
    String query,
    Emitter<DiscoverySearchState> emit,
  ) async {
    final generation = ++_generation;
    if (query.runes.length < minQueryLength) {
      _showHistory(emit);
      return;
    }
    emit(DiscoverySearchState.searching(query: query));
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
              ? DiscoverySearchState.empty(query: query)
              : DiscoverySearchState.results(
                  query: query,
                  results: results,
                  filter: _filter,
                ),
        );
        return !results.isEmpty;
      },
      (error) {
        emit(DiscoverySearchState.failure(query: query, error: error));
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
    Emitter<DiscoverySearchState> emit,
  ) async {
    final version = ++_historyVersion;
    final saved = await _history.add(query);
    if (version != _historyVersion) {
      return;
    }
    // A failed save changed nothing on disk; read what is there, because
    // this save's version dropped the list the bloc read when it started.
    final list =
        saved.getOrNull() ?? (await _history.load()).getOrElse(() => const []);
    if (version == _historyVersion) {
      _recent = list;
      _refreshHistory(emit);
    }
  }

  void _showHistory(Emitter<DiscoverySearchState> emit) =>
      emit(DiscoverySearchState.idle(history: _recent));

  /// Shows the current recent searches if they are on screen.
  void _refreshHistory(Emitter<DiscoverySearchState> emit) {
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
}
