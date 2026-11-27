import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/domain/model/comic_id.dart';
import 'package:characters_details/src/domain/repository/characters_details_repository.dart';
import 'package:characters_details/src/flow/characters_details_flow_state.dart';
import 'package:characters_details/src/navigator/characters_details_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';

part 'character_details_bloc.freezed.dart';
part 'character_details_event.dart';
part 'character_details_state.dart';

/// How long after handing a comic over a second hand-over of the same one is
/// ignored: the second tap of a double tap (P-089). By then the opened page
/// covers this one. The same value as `comics_details` and
/// `discovery_search`.
const Duration openGuard = Duration(milliseconds: 500);

/// The profile page's bloc: loads the character the flow opened on and the
/// comics it appears in, and hands a tapped comic over to the app through the
/// navigator, which only blocs call (plan 01 §4.1). A second hand-over of
/// the same comic within [openGuard] is ignored, so a double tap opens one
/// page.
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@injectable
final class CharacterDetailsBloc
    extends McBloc<CharacterDetailsEvent, CharacterDetailsState> {
  CharacterDetailsBloc(
    this._repository,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(const CharacterDetailsState.loading(), monitoring: monitoring) {
    on<CharacterDetailsEvent>(_onEvent);
    add(const CharacterDetailsEvent.load());
  }

  final CharacterDetailsRepository _repository;
  final FeatureFlowController<CharacterDetailsFlowState> _flow;
  final CharacterDetailsNavigator _navigator;

  /// True while a load is in flight: a second Retry tap does not start a
  /// second request.
  bool _loading = false;

  /// Runs for [openGuard] after a comic was handed over.
  Timer? _openGuard;

  /// What the running guard was started for.
  ComicId? _openTarget;

  Future<void> _onEvent(
    CharacterDetailsEvent event,
    Emitter<CharacterDetailsState> emit,
  ) async {
    switch (event) {
      case _Load():
        if (_loading) {
          return;
        }
        _loading = true;
        try {
          emit(const CharacterDetailsState.loading());
          final id = _flow.state.characterId;
          // Both requests start at once: the profile does not wait for the
          // comics to ask for them.
          final (character, comics) = await (
            _repository.fetchCharacter(id),
            _repository.fetchComics(id),
          ).wait;
          emit(_stateOf(character, comics));
        } finally {
          _loading = false;
        }
      case _OpenComic(:final id):
        if (_startOpenGuard(id)) {
          _navigator.openComic(id);
        }
    }
  }

  /// The character decides first: an unknown one is not found whatever the
  /// comics said; any other failure of either request fails the page, and
  /// Retry reloads both.
  CharacterDetailsState _stateOf(
    Result<Character, ApiFailure> character,
    Result<List<ComicSummary>, ApiFailure> comics,
  ) => character.fold(
    (profile) => comics.fold(
      (list) => CharacterDetailsState.success(profile, list),
      CharacterDetailsState.failure,
    ),
    (failure) => failure is ApiNotFound
        ? const CharacterDetailsState.notFound()
        : CharacterDetailsState.failure(failure),
  );

  /// False while a hand-over of the same [target] still guards (the second
  /// tap of a double tap); else starts the guard for it. A different comic
  /// goes through at once: popping back and tapping another within
  /// [openGuard] is not a double tap.
  bool _startOpenGuard(ComicId target) {
    if ((_openGuard?.isActive ?? false) && _openTarget == target) {
      return false;
    }
    _openGuard?.cancel();
    _openGuard = Timer(openGuard, () {});
    _openTarget = target;
    return true;
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    return super.close();
  }
}
