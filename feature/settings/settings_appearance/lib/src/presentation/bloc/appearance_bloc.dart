import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:settings_appearance/src/domain/settings_analytics.dart';
import 'package:settings_appearance/src/flow/settings_appearance_flow_state.dart';
import 'package:settings_appearance/src/navigator/settings_appearance_navigator.dart';

part 'appearance_bloc.freezed.dart';
part 'appearance_event.dart';
part 'appearance_state.dart';

/// The appearance settings: shows the app-wide preferences
/// (`AppearanceSettings`, ADR-0013) and changes them.
///
/// - **The appearance is the state's source.** The bloc holds no copy of its
///   own: every state is the appearance's snapshot (its values, its sync
///   status, its save failure), so a change made anywhere, and every sync,
///   shows here at once.
/// - **A change is never blocked.** Choosing a value applies it app-wide at
///   once (the appearance saves it before answering); the sync that follows
///   only moves the status. A choice equal to the current value does
///   nothing: no save, no request, no event.
/// - **Signed out**, "Sync across devices" awaits `requestSignIn()`; the
///   appearance follows whoever signs in by itself, by the documented merge
///   rule, so the bloc only waits and shows what comes.
/// - Each change is tracked once as `settings_changed`, here, where the
///   user's intent is known (ADR-0012).
@injectable
final class AppearanceBloc extends McBloc<AppearanceEvent, AppearanceState> {
  AppearanceBloc(
    this._appearance,
    this._navigator,
    this._flow,
    this._tracker,
    Monitoring monitoring,
  ) : super(const AppearanceState.loading(), monitoring: monitoring) {
    on<AppearanceEvent>(_onEvent);
  }

  final AppearanceSettings _appearance;
  final SettingsAppearanceNavigator _navigator;
  final FeatureFlowController<SettingsAppearanceFlowState> _flow;
  final AnalyticsTracker _tracker;

  StreamSubscription<AppearanceSnapshot>? _changes;

  /// The app is signing someone in for this screen.
  bool _signingIn = false;

  Future<void> _onEvent(
    AppearanceEvent event,
    Emitter<AppearanceState> emit,
  ) async {
    switch (event) {
      case _Load():
        _changes ??= _appearance.changes.listen((_) {
          // Not after the screen was left: a closed bloc takes no events.
          if (!isClosed) {
            add(const _Changed());
          }
        });
        _show(emit);
      case _Changed():
        _show(emit);
      case _SetThemeMode(:final mode):
        if (_current?.themeMode != mode) {
          _tracker.themeModeChanged(mode);
          _apply(_appearance.change(themeMode: mode), emit);
        }
      case _SetDensity(:final density):
        if (_current?.density != density) {
          _tracker.densityChanged(density);
          _apply(_appearance.change(density: density), emit);
        }
      case _SetReduceMotion(:final on):
        if (_current?.reduceMotion != on) {
          _tracker.reduceMotionChanged(on: on);
          _apply(_appearance.change(reduceMotion: on), emit);
        }
      case _Reset():
        if (_current != AppearancePreferences.defaults) {
          _tracker.resetToDefaults();
          _apply(_appearance.reset(), emit);
        }
      case _Retry():
        _apply(_appearance.retry(), emit);
      case _SyncAcrossDevices():
        await _signIn(emit);
      case _OpenAbout():
        _flow.update((s) => s.copyWith(aboutOpen: true));
    }
  }

  /// The preferences shown, or null before the first state.
  AppearancePreferences? get _current => switch (state) {
    _Ready(:final preferences) || _Failure(:final preferences) => preferences,
    _Loading() => null,
  };

  /// The appearance applied the change synchronously; its sync runs on, and
  /// shows up through [AppearanceReader.changes]. Not awaited: a sync may
  /// wait on the network for long, and must not hold up the next choice.
  void _apply(Future<void> sync, Emitter<AppearanceState> emit) {
    unawaited(sync);
    _show(emit);
  }

  Future<void> _signIn(Emitter<AppearanceState> emit) async {
    // Only signed out, and one sign-in at a time: a second tap finds it
    // signing in.
    if (_signingIn ||
        _appearance.snapshot.status != AppearanceSyncStatus.local) {
      return;
    }
    _signingIn = true;
    _show(emit);
    try {
      await _navigator.requestSignIn();
    } finally {
      _signingIn = false;
    }
    if (isClosed) {
      return;
    }
    // Whatever the answer: the appearance shows the session now current.
    _show(emit);
  }

  void _show(Emitter<AppearanceState> emit) {
    final snapshot = _appearance.snapshot;
    final failure = snapshot.saveFailure;
    emit(
      failure != null
          ? AppearanceState.failure(snapshot.preferences, failure)
          : AppearanceState.ready(
              preferences: snapshot.preferences,
              sync: snapshot.status,
              signingIn: _signingIn,
            ),
    );
  }

  @override
  Future<void> close() {
    // Not awaited: a cancel future is made in the root zone and never
    // completes under a widget test's fake async (F-0052 trap 1).
    unawaited(_changes?.cancel());
    return super.close();
  }
}
