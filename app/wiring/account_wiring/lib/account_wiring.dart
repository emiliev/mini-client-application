// The account group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
// Profile, auth and the other settings join with their features.
import 'package:account_wiring/src/routes/settings_routes.dart';
import 'package:go_router/go_router.dart';

export 'package:account_wiring/src/di/account_wiring_di_initializer.dart'
    show AccountWiringDIInitializer;
export 'package:account_wiring/src/di/di_initializer.dart'
    show AccountNavigatorsDIInitializer;
export 'package:account_wiring/src/routes/route_targets.dart'
    show AccountRouteTargets;
export 'package:account_wiring/src/routes/settings_routes.dart'
    show SettingsAppearanceRoute;

/// The account group's routes (the appearance settings; profile and auth
/// later).
List<RouteBase> get accountRoutes => <RouteBase>[...settingsRoutes];
