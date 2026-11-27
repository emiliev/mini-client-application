import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'settings_routes.g.dart';

/// The account group's settings routes (generated `$appRoutes`).
List<RouteBase> get settingsRoutes => $appRoutes;

/// `/settings/appearance`: the appearance settings. The app shell nests it
/// under home (T-0049), so a deep link
/// (`miniclient://app/settings/appearance`) opens `[home, appearance]` and
/// Back goes home. The route's name is the screen analytics tracks
/// (T-0053), and the flow's first page carries the same name (ADR-0012).
/// The settings index (`/settings`, `settings_home`) joins with its feature.
@TypedGoRoute<SettingsAppearanceRoute>(
  path: '/settings/appearance',
  name: 'settings_appearance',
)
class SettingsAppearanceRoute extends GoRouteData
    with $SettingsAppearanceRoute {
  const SettingsAppearanceRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<AccountRouteTargets>().settingsAppearance();
}
