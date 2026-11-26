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
/// - **Signed out:** a tap means "add it". It asks the app to sign in and
///   waits (`requestSignIn()`). On false nothing changes and no request is
///   made. On true it first reads the flag for the new session: if that user
///   already has the comic, nothing is written; otherwise it is saved.
/// - **Signed in:** a tap flips the toggle at once (optimistic), then writes;
///   a failed write flips it back and shows an inline error.
/// - **One at a time:** a tap while a sign-in or a write is in flight is
///   ignored, so a double tap sends one request.
/// - **The session decides:** it follows `SessionReader.authState`. A
///   sign-in elsewhere reloads the flag for that user; a sign-out (a rejected
///   refresh included) shows "not a favourite". A change during a tap is
///   applied when the tap settles.
///
/// Every saved write publishes `DataChanged('favourites')` once, and a
/// `DataChanged('favourites')` from anyone else (another page of the same
/// comic) reads the flag again.
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
    _sessionChanges = _session.authState.listen(
      (_) => add(const _SessionChanged()),
    );
    _favouriteChanges = _bus
        .onDataChanged(favouritesTopic)
        .listen((_) => add(const _FavouritesChanged()));
    add(const ComicFavouriteEvent.load());
  }

  final ComicsDetailsRepository _repository;
  final FeatureFlowController<ComicsDetailsFlowState> _flow;
  final ComicsDetailsNavigator _navigator;
  final SessionReader _session;
  final EventBus _bus;
  late final StreamSubscription<AuthStatus> _sessionChanges;
  late final StreamSubscription<DataChanged> _favouriteChanges;

  /// This bloc's own announcements still to arrive on the bus: each comes
  /// back to its publisher too, and is not a reason to read again.
  int _ownAnnouncements = 0;

  /// True from a tap until its sign-in and write settled.
  bool _busy = false;

  /// The session epoch the shown state belongs to; null before the first
  /// read. A session event for this same epoch changes nothing.
  int? _shownEpoch;

  ComicId get _comicId => _flow.state.comicId;

  Future<void> _onEvent(
    ComicFavouriteEvent event,
    Emitter<ComicFavouriteState> emit,
  ) async {
    switch (event) {
      case _Load():
        await _load(emit);
      case _FavouritesChanged():
        // Another page (or feature) wrote a favourite: read the flag again,
        // so two pages of the same comic agree.
        if (_ownAnnouncements > 0) {
          _ownAnnouncements--;
        } else if (!_busy) {
          await _load(emit);
        }
      case _SessionChanged():
        // During a tap the tap's own ending re-checks the session.
        if (!_busy && _session.epoch != _shownEpoch) {
          await _load(emit);
        }
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
        if (_session.epoch != _shownEpoch) {
          await _load(emit);
        }
    }
  }

  /// Shows the flag for the current session: "not a favourite" signed out,
  /// the backend's answer signed in. Reads again if the session changed
  /// while it was reading.
  Future<void> _load(Emitter<ComicFavouriteState> emit) async {
    final epoch = _session.epoch;
    if (!_session.isSignedIn) {
      _shownEpoch = epoch;
      emit(const ComicFavouriteState.ready(favourite: false));
      return;
    }
    emit(const ComicFavouriteState.loading());
    final result = await _repository.isFavourite(_comicId);
    if (_session.epoch != epoch) {
      return _load(emit);
    }
    _shownEpoch = epoch;
    emit(
      result.fold(
        (favourite) => ComicFavouriteState.ready(favourite: favourite),
        ComicFavouriteState.loadFailed,
      ),
    );
  }

  Future<void> _toggle(Emitter<ComicFavouriteState> emit) async {
    var current = switch (state) {
      _Ready(:final favourite) || _SaveFailed(:final favourite) => favourite,
      _LoadFailed() || _Loading() || _SigningIn() => false,
    };
    if (!_session.isSignedIn) {
      emit(const ComicFavouriteState.signingIn());
      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {
        _shownEpoch = _session.epoch;
        emit(const ComicFavouriteState.ready(favourite: false));
        return;
      }
      // A new session: its own flag decides, never the signed-out view.
      final epoch = _session.epoch;
      final fresh = await _repository.isFavourite(_comicId);
      if (_session.epoch != epoch) {
        // The session changed during the read (a sign-out, another user):
        // the answer belongs to a session that is gone, so nothing is
        // written. The tap's ending reloads for the current session.
        return;
      }
      _shownEpoch = epoch;
      final failure = fresh.fold<ApiFailure?>((_) => null, (error) => error);
      if (failure != null) {
        emit(ComicFavouriteState.loadFailed(failure));
        return;
      }
      if (fresh.getOrElse(() => false)) {
        // The tap meant "add", and this user already has it: no write.
        emit(const ComicFavouriteState.ready(favourite: true));
        return;
      }
      current = false;
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
        _ownAnnouncements++;
        _bus.publish(const DataChanged(favouritesTopic));
      },
      (error) => emit(
        ComicFavouriteState.saveFailed(error, favourite: current),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sessionChanges.cancel();
    await _favouriteChanges.cancel();
    return super.close();
  }
}
