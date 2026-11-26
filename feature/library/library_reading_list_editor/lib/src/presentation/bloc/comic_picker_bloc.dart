import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/repository/reading_list_editor_repository.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';

part 'comic_picker_bloc.freezed.dart';
part 'comic_picker_event.dart';
part 'comic_picker_state.dart';

/// Step 2's search: the comics whose title starts with what the user typed,
/// once typing pauses (`DebouncedQuery`), all comics before anything is
/// typed. Only the latest search is shown: an answer to an older query is
/// dropped. What is picked is not here; it is the wizard's (the editor
/// bloc), so it survives this page.
///
/// One per comics page (a factory): leaving the step closes it, and a late
/// answer is dropped with it.
@injectable
final class ComicPickerBloc
    extends McBloc<ComicPickerEvent, ComicPickerState> {
  ComicPickerBloc(this._repository, Monitoring monitoring)
    : super(const ComicPickerState.loading(query: ''), monitoring: monitoring) {
    _query = DebouncedQuery(
      onSearch: (query) => add(_Search(query)),
      onClear: () => add(const _Search('')),
    );
    on<ComicPickerEvent>(_onEvent);
    add(const _Search(''));
  }

  final ReadingListEditorRepository _repository;
  late final DebouncedQuery _query;

  /// The search whose answer may be shown; older answers are dropped.
  int _latest = 0;

  Future<void> _onEvent(
    ComicPickerEvent event,
    Emitter<ComicPickerState> emit,
  ) async {
    switch (event) {
      case _QueryChanged(:final text):
        _query.update(text);
      case _Retry():
        // Only after a failure, so a double Retry sends one request.
        if (state case _Failure(:final query)) {
          await _search(query, emit);
        }
      case _Search(:final query):
        await _search(query, emit);
    }
  }

  Future<void> _search(String query, Emitter<ComicPickerState> emit) async {
    final search = ++_latest;
    emit(ComicPickerState.loading(query: query));
    final result = await _repository.searchComics(query);
    if (search != _latest) {
      return;
    }
    emit(
      result.fold(
        (comics) => comics.isEmpty
            ? ComicPickerState.empty(query: query)
            : ComicPickerState.results(query: query, comics: comics),
        (failure) => ComicPickerState.failure(failure, query: query),
      ),
    );
  }

  @override
  Future<void> close() {
    _query.dispose();
    return super.close();
  }
}
