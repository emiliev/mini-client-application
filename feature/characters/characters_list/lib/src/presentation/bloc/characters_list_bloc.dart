import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/characters_query.dart';
import 'package:characters_list/src/domain/repository/characters_list_repository.dart';
import 'package:characters_list/src/flow/characters_list_flow_state.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';

part 'characters_list_bloc.freezed.dart';
part 'characters_list_event.dart';
part 'characters_list_state.dart';

/// Characters per request: the first page shows 30 (T-0032-AC1).
const int charactersPageSize = 30;

/// The list page's bloc: pages of characters through a [PagingController]
/// (load, load more, refresh, retry), and the tap that opens a preview, which
/// is flow state, not a route (plan 01 §4.1).
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@injectable
final class CharactersListBloc
    extends McBloc<CharactersListEvent, CharactersListState> {
  CharactersListBloc(this._repository, this._flow, Monitoring monitoring)
    : super(const CharactersListState.loading(), monitoring: monitoring) {
    _paging = PagingController<Character>(
      fetcher: (request) => _repository.fetchPage(
        CharactersQuery(
          offset: request.offset,
          limit: request.limit,
          teamId: _flow.state.teamId,
        ),
      ),
      // The controller reports outside any handler; an event brings each
      // state back into the bloc, so only a handler emits.
      onState: (page) => add(_PageChanged(page)),
      limit: charactersPageSize,
    );
    on<CharactersListEvent>(_onEvent);
    add(const CharactersListEvent.load());
  }

  final CharactersListRepository _repository;
  final FeatureFlowController<CharactersListFlowState> _flow;
  late final PagingController<Character> _paging;

  Future<void> _onEvent(
    CharactersListEvent event,
    Emitter<CharactersListState> emit,
  ) async {
    switch (event) {
      case _Load():
        await _paging.loadFirst();
      case _LoadMore():
        await _paging.loadMore();
      case _Retry():
        await _paging.retry();
      case _Refresh(:final done):
        try {
          await _paging.refresh();
        } finally {
          done.complete();
        }
      case _Preview(:final character):
        // One preview at a time: a second tap while the first preview slides
        // in must not replace what the open preview shows and opens.
        if (_flow.state.preview == null) {
          _flow.update((s) => s.copyWith(preview: character));
        }
      case _PageChanged(:final page):
        emit(_toState(page));
    }
  }

  /// No items yet: a failure is the full-page error, anything else is still
  /// loading. With items, or at the end of an empty list, the grid shows the
  /// page (its footer carries a later page's failure).
  static CharactersListState _toState(PagedState<Character> page) =>
      switch (page) {
        PagedState(items: [], failure: final failure?) =>
          CharactersListState.failure(failure),
        PagedState(items: [], hasReachedEnd: false) =>
          const CharactersListState.loading(),
        _ => CharactersListState.success(page),
      };

  @override
  Future<void> close() {
    _paging.dispose();
    return super.close();
  }
}
