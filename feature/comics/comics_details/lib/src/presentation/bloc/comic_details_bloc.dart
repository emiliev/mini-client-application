import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:comics_details/src/domain/repository/comics_details_repository.dart';
import 'package:comics_details/src/flow/comics_details_flow_state.dart';
import 'package:comics_details/src/navigator/comics_details_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

part 'comic_details_bloc.freezed.dart';
part 'comic_details_event.dart';
part 'comic_details_state.dart';

/// How long after handing a character or creator over a second hand-over of
/// the same one is ignored: the second tap of a double tap (P-089). By then the opened page
/// covers this one. The same value as `discovery_search`'s open guard.
const Duration openGuard = Duration(milliseconds: 500);

/// The details page's bloc: loads the comic the flow opened on (and its
/// cast), opens its cover inside the flow, and hands a tapped character or
/// creator over to the app through the navigator, which only blocs call
/// (plan 01 §4.1). A second hand-over of the same target within [openGuard] is ignored, so a
/// double tap opens one page.
///
/// Pure Dart (R15): it imports `package:bloc` through `mc_bloc_kit`, never
/// Flutter, so every generator that reads it runs on analyzer summaries.
@injectable
final class ComicDetailsBloc
    extends McBloc<ComicDetailsEvent, ComicDetailsState> {
  ComicDetailsBloc(
    this._repository,
    this._flow,
    this._navigator,
    Monitoring monitoring,
  ) : super(const ComicDetailsState.loading(), monitoring: monitoring) {
    on<ComicDetailsEvent>(_onEvent);
    add(const ComicDetailsEvent.load());
  }

  final ComicsDetailsRepository _repository;
  final FeatureFlowController<ComicsDetailsFlowState> _flow;
  final ComicsDetailsNavigator _navigator;

  /// True while a load is in flight: a second Retry tap does not start a
  /// second request.
  bool _loading = false;

  /// Runs for [openGuard] after a character or creator was handed over.
  Timer? _openGuard;

  /// What the running guard was started for.
  (String, int)? _openTarget;

  Future<void> _onEvent(
    ComicDetailsEvent event,
    Emitter<ComicDetailsState> emit,
  ) async {
    switch (event) {
      case _Load():
        if (_loading) {
          return;
        }
        _loading = true;
        try {
          emit(const ComicDetailsState.loading());
          final result = await _repository.fetchComic(_flow.state.comicId);
          emit(
            result.fold(
              ComicDetailsState.success,
              (failure) => failure is ApiNotFound
                  ? const ComicDetailsState.notFound()
                  : ComicDetailsState.failure(failure),
            ),
          );
        } finally {
          _loading = false;
        }
      case _OpenCover():
        // One cover page at a time, and only for a loaded comic.
        if (state case _Success(:final comic) when _flow.state.cover == null) {
          _flow.update((s) => s.copyWith(cover: comic));
        }
      case _OpenCharacter(:final id):
        if (_startOpenGuard(('character', id.value))) {
          // mcgen:keep details.openCharacter
          _navigator.openCharacter(id);
          // mcgen:end details.openCharacter
        }
      case _OpenCreator(:final id):
        if (_startOpenGuard(('creator', id.value))) {
          // mcgen:keep details.openCreator
          _navigator.openCreator(id);
          // mcgen:end details.openCreator
        }
    }
  }

  /// False while a hand-over of the same [target] still guards (the second
  /// tap of a double tap); else starts the guard for it. A different target
  /// goes through at once: popping back and tapping something else within
  /// [openGuard] is not a double tap.
  bool _startOpenGuard((String, int) target) {
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
