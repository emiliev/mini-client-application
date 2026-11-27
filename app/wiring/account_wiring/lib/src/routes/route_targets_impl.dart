import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class AccountRouteTargetsImpl implements AccountRouteTargets {
  const AccountRouteTargetsImpl({
    required SettingsAppearanceNavigator settingsAppearance,
  }) : _settingsAppearance = settingsAppearance;

  final SettingsAppearanceNavigator _settingsAppearance;

  @override
  SettingsAppearanceFlow settingsAppearance() =>
      SettingsAppearanceFlow(navigator: _settingsAppearance);
}
