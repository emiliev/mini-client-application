import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_session/mc_session.dart';
import 'package:settings_home/settings_home.dart';

/// settings_home's way out of the feature. It holds the [RouterRef], not a
/// router, and asks for the live router at each call (T-0033).
///
/// - **Appearance** is pushed from the index (`AppLocations`: the typed route
///   belongs to the same wiring, but the location is the one the app's links
///   use), so the stack is `[home, settings, appearance]` and Back lands on
///   the index.
/// - **Signing in** is the app's business: `requestAppSignIn` (app_core)
///   opens the sign-in screen (T-0066), with no reason of its own.
/// - **Signing out** goes through the auth port (`AuthApi.signOut`, as home's
///   entry does): the session ends at once and the server is told, best
///   effort. The feature only reads the session.
@LazySingleton(as: SettingsHomeNavigator)
class SettingsHomeNavigatorImpl implements SettingsHomeNavigator {
  SettingsHomeNavigatorImpl(this._routerRef, this._session, this._auth);

  final RouterRef _routerRef;
  final SessionReader _session;
  final AuthApi _auth;

  @override
  void openAppearance() {
    unawaited(_routerRef.router.push(AppLocations.settingsAppearance));
  }

  /// True at once when someone is signed in; otherwise the sign-in screen's
  /// answer (true only once a session exists). False when there is no
  /// navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestAppSignIn(
    routerRef: _routerRef,
    session: _session,
    purpose: null,
  );

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
