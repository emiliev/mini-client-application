import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_session/mc_session.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// settings_appearance's way out of the feature. It holds the [RouterRef],
/// not a router, and asks for the live router at each call (T-0033).
///
/// Signing in is the app's business: the temporary fixture sheet that
/// `app_core` shares between the wirings signs a fixture user in (P-044).
/// The appearance follows whoever signs in by itself (ADR-0013).
@LazySingleton(as: SettingsAppearanceNavigator)
class SettingsAppearanceNavigatorImpl implements SettingsAppearanceNavigator {
  SettingsAppearanceNavigatorImpl(this._routerRef, this._session, this._auth);

  final RouterRef _routerRef;
  final SessionReader _session;
  final AuthApi _auth;

  /// True at once when someone is signed in; otherwise the sheet's answer.
  /// False when there is no navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestFixtureSignIn(
    routerRef: _routerRef,
    session: _session,
    auth: _auth,
    reason: 'to sync your appearance across devices',
  );
}
