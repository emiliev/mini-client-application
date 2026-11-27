import 'package:auth_signin/auth_signin.dart';
import 'package:flutter/foundation.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// What the account group's typed routes build (R15): each member returns a
/// feature's `*Flow`. The route files import only this interface;
/// `AccountRouteTargetsImpl` (unannotated) supplies the flows' navigators
/// and is registered by `AccountWiringDIInitializer`.
///
/// Prefixed with the group (`CommerceRouteTargets`, ...) because the app
/// imports every wiring's barrel side by side (F-0040 fact 11).
abstract interface class AccountRouteTargets {
  /// The appearance settings: `/settings/appearance`.
  SettingsAppearanceFlow settingsAppearance();

  /// The sign-in form: `/auth/sign-in`. [reason] is the `reason` code of the
  /// link (an unknown or absent one says nothing). [onComplete] gets the
  /// app-level result, true when someone signed in: features never share
  /// types (plan 01 §4.3).
  AuthSignInFlow signIn({
    required ValueChanged<bool> onComplete,
    String? reason,
  });
}
