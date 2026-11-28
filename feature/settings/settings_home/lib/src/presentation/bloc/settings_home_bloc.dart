import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:settings_home/src/domain/account_profile_reader.dart';
import 'package:settings_home/src/domain/model/about_info.dart';
import 'package:settings_home/src/domain/model/account_view.dart';
import 'package:settings_home/src/navigator/settings_home_navigator.dart';

part 'settings_home_bloc.freezed.dart';
part 'settings_home_event.dart';
part 'settings_home_state.dart';

/// The settings index: who is signed in, the theme the Appearance row shows,
/// and About.
///
/// - **The session decides.** The account section follows
///   `SessionReader.authState`: a sign-in, a sign-out or a user switch
///   anywhere shows the session now current, once per session epoch. Sign in
///   and Sign out ask the app (`SettingsHomeNavigator`) and wait, but the
///   session, not the answer, decides what shows next.
/// - **Every await is a session boundary** (F-0040 fact 21): the profile
///   read of one session that is answered under another is dropped before
///   any state is written (the request itself is pinned to its epoch,
///   T-0050), and the page reads again for the session now current. A
///   same-user re-sign-in sends no `authState` event, so the dropped answer
///   is what triggers it.
/// - **The subtitle follows the appearance** (`AppearanceReader.changes`),
///   so a theme chosen on the Appearance page shows when the user comes back.
/// - **About is read once** from the app's config.
/// - A failed profile read is not an error screen: the user is named by id
///   and the page still works.
@injectable
final class SettingsHomeBloc
    extends McBloc<SettingsHomeEvent, SettingsHomeState> {
  SettingsHomeBloc(
    this._session,
    this._appearance,
    this._profileReader,
    this._navigator,
    AppConfig config,
    Monitoring monitoring,
  ) : _about = AboutInfo.fromConfig(config),
      super(const SettingsHomeState.loading(), monitoring: monitoring) {
    on<SettingsHomeEvent>(_onEvent);
  }

  final SessionReader _session;
  final AppearanceReader _appearance;
  final AccountProfileReader _profileReader;
  final SettingsHomeNavigator _navigator;
  final AboutInfo _about;

  StreamSubscription<AuthStatus>? _sessionChanges;
  StreamSubscription<AppearanceSnapshot>? _appearanceChanges;

  /// The session epoch the page last started to show. A session event for
  /// this same epoch changes nothing.
  int? _shownEpoch;

  /// The profile read for the user it names, or null (not read yet, or the
  /// read failed). Only shown for the user signed in now.
  UserProfile? _profile;

  bool _signingIn = false;
  bool _signingOut = false;

  Future<void> _onEvent(
    SettingsHomeEvent event,
    Emitter<SettingsHomeState> emit,
  ) async {
    switch (event) {
      case _Load():
        // Guarded: an event can still arrive between `close()` and the
        // cancel taking effect.
        _sessionChanges ??= _session.authState.listen((_) {
          if (!isClosed) {
            add(const _SessionChanged());
          }
        });
        _appearanceChanges ??= _appearance.changes.listen((_) {
          if (!isClosed) {
            add(const _AppearanceChanged());
          }
        });
        await _show(emit);
      case _SessionChanged():
        if (_session.epoch != _shownEpoch) {
          await _show(emit);
        }
      case _AppearanceChanged():
        _emitReady(emit);
      case _SignIn():
        await _signIn(emit);
      case _SignOut():
        _signOut(emit);
      case _SignOutEnded():
        _signingOut = false;
        await _afterAuthChange(emit);
      case _OpenAppearance():
        _navigator.openAppearance();
    }
  }

  /// Shows the account for the session now current: signed out, or the user
  /// by id at once and by name when the profile arrives.
  Future<void> _show(Emitter<SettingsHomeState> emit) async {
    final epoch = _session.epoch;
    final userId = _session.userId;
    _shownEpoch = epoch;
    if (_profile?.id != userId) {
      _profile = null;
    }
    if (userId == null) {
      // The session is gone: a sign-out is done for this page, even while
      // the app still waits for the server's answer.
      _signingOut = false;
    }
    _emitReady(emit);
    if (userId == null || _profile != null) {
      return;
    }
    final result = await _profileReader.read(epoch: epoch);
    if (isClosed) {
      return;
    }
    if (_session.epoch != epoch) {
      // An answer for a session that is gone is dropped, and the page reads
      // again for the session now current.
      add(const _SessionChanged());
      return;
    }
    _profile = result.getOrNull();
    _emitReady(emit);
  }

  Future<void> _signIn(Emitter<SettingsHomeState> emit) async {
    // Only signed out, and one sign-in at a time: a second tap finds it
    // signing in.
    if (_signingIn || _session.isSignedIn) {
      return;
    }
    _signingIn = true;
    _emitReady(emit);
    try {
      await _navigator.requestSignIn();
    } on Object catch (error, stackTrace) {
      // The app could not sign anyone in: reported, and the page offers
      // Sign in again.
      if (!isClosed) {
        addError(error, stackTrace);
      }
    } finally {
      _signingIn = false;
    }
    await _afterAuthChange(emit);
  }

  /// Not awaited: the app ends the session at once and then waits for the
  /// server (best effort), and the page must not wait with it. The busy flag
  /// clears when the session changes (`_show`), or when the app answers,
  /// whichever comes first.
  void _signOut(Emitter<SettingsHomeState> emit) {
    if (_signingOut || !_session.isSignedIn) {
      return;
    }
    _signingOut = true;
    _emitReady(emit);
    unawaited(
      Future<void>.sync(_navigator.signOut)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              if (!isClosed) {
                addError(error, stackTrace);
              }
            },
          )
          .whenComplete(() {
            if (!isClosed) {
              add(const _SignOutEnded());
            }
          }),
    );
  }

  /// Whatever the app answered, the page shows the session now current: a
  /// change that already reloaded it left nothing to do but clear the busy
  /// flag.
  Future<void> _afterAuthChange(Emitter<SettingsHomeState> emit) async {
    if (isClosed) {
      return;
    }
    if (_session.epoch != _shownEpoch) {
      await _show(emit);
    } else {
      _emitReady(emit);
    }
  }

  /// The page as the session, the appearance and the config say it is now.
  void _emitReady(Emitter<SettingsHomeState> emit) {
    final userId = _session.userId;
    emit(
      SettingsHomeState.ready(
        account: userId == null
            ? const SignedOutAccount()
            : SignedInAccount(
                userId,
                profile: _profile?.id == userId ? _profile : null,
              ),
        themeMode: _appearance.snapshot.preferences.themeMode,
        about: _about,
        busy: _signingIn || _signingOut,
      ),
    );
  }

  @override
  Future<void> close() {
    // Not awaited: a cancel future is made in the root zone and never
    // completes under a widget test's fake async (F-0052 trap 1).
    unawaited(_sessionChanges?.cancel());
    unawaited(_appearanceChanges?.cancel());
    return super.close();
  }
}
