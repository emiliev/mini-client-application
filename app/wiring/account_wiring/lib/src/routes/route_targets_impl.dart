import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:auth_signin/auth_signin.dart';
import 'package:flutter/foundation.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it), and maps each flow's result to the app-level type.
class AccountRouteTargetsImpl implements AccountRouteTargets {
  const AccountRouteTargetsImpl({
    required SettingsAppearanceNavigator settingsAppearance,
    required AuthSignInNavigator authSignIn,
  }) : _settingsAppearance = settingsAppearance,
       _authSignIn = authSignIn;

  final SettingsAppearanceNavigator _settingsAppearance;
  final AuthSignInNavigator _authSignIn;

  @override
  SettingsAppearanceFlow settingsAppearance() =>
      SettingsAppearanceFlow(navigator: _settingsAppearance);

  /// The demo accounts are the mocked backend's fixture users, as the app
  /// has no other backend (a real one would pass none).
  @override
  AuthSignInFlow signIn({
    required ValueChanged<bool> onComplete,
    String? reason,
  }) => AuthSignInFlow(
    navigator: _authSignIn,
    reason: SignInReason.parse(reason),
    demoAccounts: [
      for (final user in fixtureUsers)
        DemoAccount(
          email: user.email,
          password: user.password,
          displayName: user.displayName,
        ),
    ],
    onComplete: (result) => onComplete(result == SignInResult.signedIn),
  );
}
