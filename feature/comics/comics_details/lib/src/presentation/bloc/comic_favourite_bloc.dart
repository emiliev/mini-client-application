import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/repository/comics_details_repository.dart';
import 'package:comics_details/src/flow/comics_details_flow_state.dart';
import 'package:comics_details/src/navigator/comics_details_navigator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';

part 'comic_favourite_bloc.freezed.dart';
part 'comic_favourite_event.dart';
part 'comic_favourite_state.dart';

/// The `mc_event_bus` topic a favourite write announces (P1-18 AC6), so
/// whatever lists favourites refreshes.
const String favouritesTopic = 'favourites';

/// The favourite toggle's bloc.
///
/// - **Signed out:** a tap asks the app to sign in and waits for it
///   (`requestSignIn()`). On true the favourite is saved; on false nothing
///   changes and no request is made.
/// - **Signed in:** a tap flips the toggle at once (optimistic), then writes;
///   a failed write flips it back and shows an inline error.
/// - **One at a time:** a tap while a sign-in or a write is in flight is
///   ignored, so a double tap sends one request.
///
/// Every saved write publishes `DataChanged('favourites')` once.
@injectable
final class ComicFavouriteBloc
    extends McBloc<ComicFavouriteEvent, ComicFavouriteState> {
  ComicFavouriteBloc(
    this._repository,
    this._flow,
    this._navigator,
    this._session,
    this._bus,
    Monitoring monitoring,
  ) : super(const ComicFavouriteState.loading(), monitoring: monitoring) {
    on<ComicFavouriteEvent>(_onEvent);
    add(const ComicFavouriteEvent.load());
  }

  final ComicsDetailsRepository _repository;
  final FeatureFlowController<ComicsDetailsFlowState> _flow;
  final ComicsDetailsNavigator _navigator;
  final SessionReader _session;
  final EventBus _bus;

  /// True from a tap until its sign-in and write settled.
  bool _busy = false;

  ComicId get _comicId => _flow.state.comicId;

  Future<void> _onEvent(
    ComicFavouriteEvent event,
    Emitter<ComicFavouriteState> emit,
  ) async {
    switch (event) {
      case _Load():
        if (!_session.isSignedIn) {
          emit(const ComicFavouriteState.ready(favourite: false));
          return;
        }
        final result = await _repository.isFavourite(_comicId);
        emit(
          result.fold(
            (favourite) => ComicFavouriteState.ready(favourite: favourite),
            ComicFavouriteState.loadFailed,
          ),
        );
      case _Toggle():
        if (_busy || state is _Loading) {
          return;
        }
        _busy = true;
        try {
          await _toggle(emit);
        } finally {
          _busy = false;
        }
    }
  }

  Future<void> _toggle(Emitter<ComicFavouriteState> emit) async {
    final current = switch (state) {
      _Ready(:final favourite) || _SaveFailed(:final favourite) => favourite,
      _LoadFailed() || _Loading() => false,
    };
    if (!_session.isSignedIn) {
      emit(ComicFavouriteState.ready(favourite: current, saving: true));
      if (!await _navigator.requestSignIn()) {
        emit(ComicFavouriteState.ready(favourite: current));
        return;
      }
    }
    final wanted = !current;
    emit(ComicFavouriteState.ready(favourite: wanted, saving: true));
    final result = await _repository.setFavourite(
      _comicId,
      favourite: wanted,
    );
    result.fold(
      (saved) {
        emit(ComicFavouriteState.ready(favourite: saved));
        _bus.publish(const DataChanged(favouritesTopic));
      },
      (error) => emit(
        ComicFavouriteState.saveFailed(error, favourite: current),
      ),
    );
  }
}
