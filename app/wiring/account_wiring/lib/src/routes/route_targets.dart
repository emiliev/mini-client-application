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
}
