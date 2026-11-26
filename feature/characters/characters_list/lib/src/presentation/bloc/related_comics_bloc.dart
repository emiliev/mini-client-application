import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/comic_id.dart';
import 'package:characters_list/src/domain/model/related_comic.dart';
import 'package:characters_list/src/domain/repository/characters_list_repository.dart';
import 'package:characters_list/src/navigator/characters_list_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

part 'related_comics_bloc.freezed.dart';

/// What the preview's related comics ask for.
sealed class RelatedComicsEvent {
  const RelatedComicsEvent();

  /// Loads the comics (again): the first load, and Retry after a failure.
  const factory RelatedComicsEvent.load() = _Load;

  /// A comic was tapped: hand it over to the app.
  const factory RelatedComicsEvent.open(ComicId id) = _Open;
}

final class _Load extends RelatedComicsEvent {
  const _Load();
}

final class _Open extends RelatedComicsEvent {
  const _Open(this.id);

  final ComicId id;
}

/// Tide's state shape: private cases read with `state.when` (R16).
@freezed
sealed class RelatedComicsState with _$RelatedComicsState {
  const factory RelatedComicsState.loading() = _Loading;

  /// The comics, in title order (perhaps none).
  const factory RelatedComicsState.success(List<RelatedComic> comics) =
      _Success;

  /// The comics could not be loaded; the preview itself still shows.
  @Implements<McFailureState>()
  const factory RelatedComicsState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}

/// The preview's related comics (T-0041, P-068): the first comics the
/// character appears in, each leaving the feature through the navigator's
/// `openComic`, which only blocs call (plan 01 §4.1). Its own bloc, so a
/// failure here never hides the preview.
@injectable
final class RelatedComicsBloc
    extends McBloc<RelatedComicsEvent, RelatedComicsState> {
  RelatedComicsBloc(
    @factoryParam Character character,
    this._repository,
    this._navigator,
    Monitoring monitoring,
  ) : _character = character,
      super(const RelatedComicsState.loading(), monitoring: monitoring) {
    on<RelatedComicsEvent>(_onEvent);
    add(const RelatedComicsEvent.load());
  }

  final Character _character;
  final CharactersListRepository _repository;
  final CharactersListNavigator _navigator;

  /// True while a load is in flight: a second Retry tap does not start a
  /// second request.
  bool _loading = false;

  Future<void> _onEvent(
    RelatedComicsEvent event,
    Emitter<RelatedComicsState> emit,
  ) async {
    switch (event) {
      case _Load():
        if (_loading) {
          return;
        }
        _loading = true;
        try {
          emit(const RelatedComicsState.loading());
          final result = await _repository.fetchRelatedComics(_character.id);
          emit(
            result.fold(
              RelatedComicsState.success,
              RelatedComicsState.failure,
            ),
          );
        } finally {
          _loading = false;
        }
      case _Open(:final id):
        _navigator.openComic(id);
    }
  }
}
