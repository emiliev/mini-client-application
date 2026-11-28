// The universe group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
import 'package:go_router/go_router.dart';
import 'package:universe_wiring/src/routes/characters_routes.dart';

export 'package:universe_wiring/src/di/di_initializer.dart'
    show UniverseNavigatorsDIInitializer;
export 'package:universe_wiring/src/di/universe_wiring_di_initializer.dart'
    show UniverseWiringDIInitializer;
export 'package:universe_wiring/src/routes/characters_routes.dart'
    show CharacterDetailsRoute, CharactersRoute, CharactersSearchRoute;
export 'package:universe_wiring/src/routes/route_targets.dart'
    show UniverseRouteTargets;

/// The universe group's routes (characters; teams and locations later).
List<RouteBase> get universeRoutes => <RouteBase>[...charactersRoutes];
