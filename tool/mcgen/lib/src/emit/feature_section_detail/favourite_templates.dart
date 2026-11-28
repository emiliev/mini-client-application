// Generated once from the characters_details exemplar by T-0072, then
// maintained by hand: the favourite toggle's templates (raw text with
// `<<name>>` placeholders, `«Ref»`s and `[flag]` line prefixes; see `tpl`).

const favouriteTopicTemplate =
    r'''/// The `mc_event_bus` topic a favourite write announces (P1-18 AC6), so
/// whatever lists favourites refreshes.
const String favouritesTopic = 'favourites';
''';
const favouriteBlocTemplate = r'''@«injectable»
final class <<Item>>FavouriteBloc
    extends «McBloc»<<<Item>>FavouriteEvent, <<Item>>FavouriteState> {
  <<Item>>FavouriteBloc(
    this._repository,
    this._flow,
    this._navigator,
    this._session,
    this._bus,
[analytics]    this._analytics,
    «Monitoring» monitoring,
  ) : super(const <<Item>>FavouriteState.loading(), monitoring: monitoring) {
    on<<<Item>>FavouriteEvent>(_onEvent);
    _sessionChanges = _session.authState.listen(
      (_) => add(const _SessionChanged()),
    );
    _favouriteChanges = _bus
        .onDataChanged(favouritesTopic)
        .listen((_) => add(const _FavouritesChanged()));
    add(const <<Item>>FavouriteEvent.load());
  }

  final «<<Prefix>>Repository» _repository;
  final «FeatureFlowController»<«<<Prefix>>FlowState»> _flow;
  final «<<Navigator>>» _navigator;
  final «SessionReader» _session;
  final «EventBus» _bus;
[analytics]  final «AnalyticsTracker» _analytics;
  late final StreamSubscription<«AuthStatus»> _sessionChanges;
  late final StreamSubscription<«DataChanged»> _favouriteChanges;

  /// This bloc's own announcements still to arrive on the bus: each comes
  /// back to its publisher too, and is not a reason to read again.
  int _ownAnnouncements = 0;

  /// True from a tap until its sign-in and write settled.
  bool _busy = false;

  /// An announcement arrived while a tap was in flight: read the flag again
  /// once the tap settles (it was dropped for good before the review round).
  bool _stale = false;

  /// Numbers every read; only the newest one may write its answer, so reads
  /// that finish out of order cannot show an older value.
  int _loadSeq = 0;

  /// The session epoch the shown state belongs to; null before the first
  /// read. A session event for this same epoch changes nothing.
  int? _shownEpoch;

  «<<IdType>>» get _<<itemCamel>>Id => _flow.state.<<idArg>>;

  Future<void> _onEvent(
    <<Item>>FavouriteEvent event,
    «Emitter»<<<Item>>FavouriteState> emit,
  ) async {
    switch (event) {
      case _Load():
        await _load(emit);
      case _FavouritesChanged():
        // Another page (or feature) wrote a favourite: read the flag again,
        // so two pages of the same <<item>> agree.
        if (_ownAnnouncements > 0) {
          _ownAnnouncements--;
        } else if (!_busy) {
          await _load(emit);
        } else {
          _stale = true;
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
        // A read still in flight predates this tap: it must not overwrite
        // what the tap shows or saves.
        _loadSeq++;
        try {
          await _toggle(emit);
        } finally {
          _busy = false;
        }
        if (_session.epoch != _shownEpoch || _stale) {
          await _load(emit);
        }
    }
  }

  /// Shows the flag for the current session: "not a favourite" signed out,
  /// the backend's answer signed in. Reads again if the session changed
  /// while it was reading.
  Future<void> _load(«Emitter»<<<Item>>FavouriteState> emit) async {
    final epoch = _session.epoch;
    if (!_session.isSignedIn) {
      _shownEpoch = epoch;
      emit(const <<Item>>FavouriteState.ready(favourite: false));
      return;
    }
    // A background refresh (same session, a value already shown) keeps that
    // value on screen: `loading` is for the first read and a new session.
    if (_shownEpoch != epoch || state is! _Ready) {
      emit(const <<Item>>FavouriteState.loading());
    }
    final seq = ++_loadSeq;
    _stale = false;
    final result = await _repository.isFavourite(_<<itemCamel>>Id);
    if (seq != _loadSeq) {
      // A newer read started meanwhile and owns the answer.
      return;
    }
    if (_session.epoch != epoch) {
      return _load(emit);
    }
    _shownEpoch = epoch;
    emit(
      result.fold(
        (favourite) => <<Item>>FavouriteState.ready(favourite: favourite),
        <<Item>>FavouriteState.loadFailed,
      ),
    );
  }

  Future<void> _toggle(«Emitter»<<<Item>>FavouriteState> emit) async {
    var current = switch (state) {
      _Ready(:final favourite) || _SaveFailed(:final favourite) => favourite,
      _LoadFailed() || _Loading() || _SigningIn() => false,
    };
    if (!_session.isSignedIn) {
      emit(const <<Item>>FavouriteState.signingIn());
      if (!await _navigator.requestSignIn() || !_session.isSignedIn) {
        _shownEpoch = _session.epoch;
        emit(const <<Item>>FavouriteState.ready(favourite: false));
        return;
      }
      // A new session: its own flag decides, never the signed-out view.
      final epoch = _session.epoch;
      final fresh = await _repository.isFavourite(_<<itemCamel>>Id);
      if (_session.epoch != epoch) {
        // The session changed during the read (a sign-out, another user):
        // the answer belongs to a session that is gone, so nothing is
        // written. The tap's ending reloads for the current session.
        return;
      }
      _shownEpoch = epoch;
      final failure = fresh.fold<«ApiFailure»?>((_) => null, (error) => error);
      if (failure != null) {
        emit(<<Item>>FavouriteState.loadFailed(failure));
        return;
      }
      if (fresh.getOrElse(() => false)) {
        // The tap meant "add", and this user already has it: no write.
        emit(const <<Item>>FavouriteState.ready(favourite: true));
        return;
      }
      current = false;
    }
    // The toggle came from the state of `_shownEpoch`. If the session has
    // moved on and the bloc has not heard yet (its `_SessionChanged` is still
    // queued), the tap is dropped: it would write what another user never
    // saw. The tap's ending reloads for the current session.
    final epoch = _shownEpoch;
    if (epoch == null || epoch != _session.epoch) {
      return;
    }
    final wanted = !current;
    emit(<<Item>>FavouriteState.ready(favourite: wanted, saving: true));
    final result = await _repository.setFavourite(
      _<<itemCamel>>Id,
      favourite: wanted,
      // The epoch checked just above: the request is not sent for any
      // other (T-0050), whatever happens before it leaves.
      epoch: epoch,
    );
    result.fold(
      (saved) {
        emit(<<Item>>FavouriteState.ready(favourite: saved));
[analytics]        if (saved && wanted) {
[analytics]          _analytics.<<analyticsMethod>>«!<<analyticsExt>>»(_<<itemCamel>>Id);
[analytics]        }
        _ownAnnouncements++;
        _bus.publish(const «DataChanged»(favouritesTopic));
      },
      (error) => emit(
        <<Item>>FavouriteState.saveFailed(error, favourite: current),
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
''';
const favouriteEventTemplate = r'''sealed class <<Item>>FavouriteEvent {
  const <<Item>>FavouriteEvent();

  /// Reads whether the <<item>> is a favourite (signed in), or shows it as not
  /// one (signed out).
  const factory <<Item>>FavouriteEvent.load() = _Load;

  /// The toggle was tapped (ignored while a sign-in or a write is in flight).
  const factory <<Item>>FavouriteEvent.toggle() = _Toggle;
}

final class _Load extends <<Item>>FavouriteEvent {
  const _Load();
}

final class _Toggle extends <<Item>>FavouriteEvent {
  const _Toggle();
}

/// Internal: `SessionReader.authState` changed (a sign-in or a sign-out,
/// here or anywhere else in the app).
final class _SessionChanged extends <<Item>>FavouriteEvent {
  const _SessionChanged();
}

/// Internal: someone else announced `DataChanged('favourites')` on the bus.
final class _FavouritesChanged extends <<Item>>FavouriteEvent {
  const _FavouritesChanged();
}
''';
const favouriteStateTemplate = r'''@«freezed»
sealed class <<Item>>FavouriteState with _$<<Item>>FavouriteState {
  /// Reading the flag (signed in only); the toggle waits.
  const factory <<Item>>FavouriteState.loading() = _Loading;

  /// The app is signing someone in for this tap (`requestSignIn()`); the
  /// toggle waits and still offers to add.
  const factory <<Item>>FavouriteState.signingIn() = _SigningIn;

  /// The toggle shows [favourite]. [saving] while a write is in flight;
  /// [favourite] is then already the value being written (optimistic).
  const factory <<Item>>FavouriteState.ready({
    required bool favourite,
    @Default(false) bool saving,
  }) = _Ready;

  /// The flag could not be read; the toggle shows "not a favourite" and an
  /// inline error. `McBloc` reports it to monitoring.
  @«Implements»<«McFailureState»>()
  const factory <<Item>>FavouriteState.loadFailed(
    «ApiFailure» error, {
    StackTrace? stackTrace,
  }) = _LoadFailed;

  /// A write failed: the toggle is back at [favourite], the value before the
  /// tap, with an inline error. `McBloc` reports it to monitoring.
  @«Implements»<«McFailureState»>()
  const factory <<Item>>FavouriteState.saveFailed(
    «ApiFailure» error, {
    required bool favourite,
    StackTrace? stackTrace,
  }) = _SaveFailed;
}
''';
const favouriteToggleTemplate =
    r'''/// Key of the favourite toggle's inline error, for tests.
const favouriteErrorKey = ValueKey<String>('<<module>>.favourite.error');

/// The favourite toggle: a button whose label says what a tap does, and an
/// inline error below it after a failed read or write. A tap dispatches an
/// event; only the bloc decides (sign in first, write, roll back).
class FavouriteToggle extends StatelessWidget {
  const FavouriteToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = «<<Prefix>>L10n».of(context);
    return «BlocBuilder»<«<<Item>>FavouriteBloc», «<<Item>>FavouriteState»>(
      builder: (context, state) {
        void toggle() => context.read<«<<Item>>FavouriteBloc»>().add(
          const «<<Item>>FavouriteEvent».toggle(),
        );
        final (favourite, enabled, error) = state.when(
          loading: () => (false, false, null),
          signingIn: () => (false, false, null),
          ready: (favourite, saving) => (favourite, !saving, null),
          loadFailed: (_, _) => (
            false,
            true,
            l10n.<<prefixCamel>>FavouriteLoadFailed,
          ),
          saveFailed: (_, favourite, _) => (
            favourite,
            true,
            l10n.<<prefixCamel>>FavouriteSaveFailed,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              toggled: favourite,
              child: «McButton»(
                label: favourite
                    ? l10n.<<prefixCamel>>FavouriteRemove
                    : l10n.<<prefixCamel>>FavouriteAdd,
                variant: favourite
                    ? «McButtonVariant».secondary
                    : «McButtonVariant».primary,
                onPressed: enabled ? toggle : null,
              ),
            ),
            if (error != null) ...[
              const «McGap».xs(),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  key: favouriteErrorKey,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mcPalette.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
''';
