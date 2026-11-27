// The chronicle group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
// Events and stories join with their features.
import 'package:chronicle_wiring/src/routes/trivia_routes.dart';
import 'package:go_router/go_router.dart';

export 'package:chronicle_wiring/src/di/chronicle_wiring_di_initializer.dart'
    show ChronicleWiringDIInitializer, chronicleClock, chronicleSeed;
export 'package:chronicle_wiring/src/di/di_initializer.dart'
    show ChronicleNavigatorsDIInitializer;
export 'package:chronicle_wiring/src/routes/route_targets.dart'
    show ChronicleRouteTargets;
export 'package:chronicle_wiring/src/routes/trivia_routes.dart'
    show TriviaPlayRoute, TriviaRoute;

/// The chronicle group's routes (the trivia; events and stories later).
List<RouteBase> get chronicleRoutes => <RouteBase>[...triviaRoutes];
