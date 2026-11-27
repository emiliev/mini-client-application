import 'package:app_core/app_core.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_session/mc_session.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// settings_appearance's way out of the feature. It holds the [RouterRef],
/// not a router, and asks for the live router at each call (T-0033).
///
/// Signing in is the app's business: `requestAppSignIn` (app_core) opens the
/// sign-in screen (T-0066).
/// The appearance follows whoever signs in by itself (ADR-0013).
@LazySingleton(as: SettingsAppearanceNavigator)
class SettingsAppearanceNavigatorImpl implements SettingsAppearanceNavigator {
  SettingsAppearanceNavigatorImpl(this._routerRef, this._session);

  final RouterRef _routerRef;
  final SessionReader _session;

  /// True at once when someone is signed in; otherwise the sign-in screen's
  /// answer (true only once a session exists). False when there is no
  /// navigator to show it on.
  @override
  Future<bool> requestSignIn() => requestAppSignIn(
    routerRef: _routerRef,
    session: _session,
    purpose: SignInPurpose.appearanceSync,
  );
}
