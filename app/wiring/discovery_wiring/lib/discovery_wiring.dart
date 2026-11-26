// The discovery group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
// Home, notifications, help and system join with their features.
import 'package:discovery_wiring/src/routes/search_routes.dart';
import 'package:go_router/go_router.dart';

export 'package:discovery_wiring/src/di/di_initializer.dart'
    show DiscoveryNavigatorsDIInitializer;
export 'package:discovery_wiring/src/di/discovery_wiring_di_initializer.dart'
    show DiscoveryWiringDIInitializer;
export 'package:discovery_wiring/src/routes/route_targets.dart'
    show DiscoveryRouteTargets;
export 'package:discovery_wiring/src/routes/search_routes.dart'
    show SearchRoute;

/// The discovery group's routes (search; home and the rest later).
List<RouteBase> get discoveryRoutes => <RouteBase>[...searchRoutes];
