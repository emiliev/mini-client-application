import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'settings_routes.g.dart';

/// The account group's settings routes (generated `$appRoutes`).
List<RouteBase> get settingsRoutes => $appRoutes;

/// `/settings`: the settings index (T-0070), with `/settings/appearance`
/// nested under it. The app shell nests the whole tree under home (T-0049),
/// so a link to either opens the stack home → settings (→ appearance) and
/// Back walks it. The routes' names are the screens analytics tracks
/// (T-0053), and each flow's first page carries the same name (ADR-0012).
///
/// The child's `location` is `/settings/appearance`: its path here is
/// relative (go_router's rule for a sub-route), the typed route writes the
/// full one.
@TypedGoRoute<SettingsHomeRoute>(
  path: '/settings',
  name: 'settings_home',
  routes: [
    TypedGoRoute<SettingsAppearanceRoute>(
      path: 'appearance',
      name: 'settings_appearance',
    ),
  ],
)
class SettingsHomeRoute extends GoRouteData with $SettingsHomeRoute {
  const SettingsHomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<AccountRouteTargets>().settingsHome();
}

/// `/settings/appearance`: the appearance settings, above the index.
class SettingsAppearanceRoute extends GoRouteData
    with $SettingsAppearanceRoute {
  const SettingsAppearanceRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<AccountRouteTargets>().settingsAppearance();
}
