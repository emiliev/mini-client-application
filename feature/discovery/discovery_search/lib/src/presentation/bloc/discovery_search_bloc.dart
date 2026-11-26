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
/// CONTRACT.md); a shorter one sends no request.
const int minQueryLength = 2;

/// The search page's bloc: turns the field's edits into one debounced
/// request per pause, shows only the latest query's answer, remembers the
/// queries that found something, and hands a tapped result over to the app
/// through the navigator, which only blocs call (plan 01 §4.1).
///
/// - **Debounce:** `mc_paging`'s `DebouncedQuery` ([searchDebounce]). A
///   query shorter than [minQueryLength] shows the recent searches and sends
///   nothing.
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
///   latest one's answer is shown.
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
    // A flow opened with a query searches it as if it had been typed.
    if (_flow.state.initialQuery case final query?) {
      _query.update(query);
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

  Future<void> _onEvent(
    DiscoverySearchEvent event,
    Emitter<DiscoverySearchState> emit,
  ) async {
    switch (event) {
      case _QueryChanged(:final text):
        // Debounced: `_Search` or `_Cleared` comes back when typing pauses
        // (or at once for an empty field).
        _query.update(text);
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
        _historyVersion++;
        _recent = const [];
        _refreshHistory(emit);
        await _history.clear();
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
    if (version == _historyVersion) {
      saved.fold((list) {
        _recent = list;
        _refreshHistory(emit);
      }, (_) {});
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
    return super.close();
  }
}
