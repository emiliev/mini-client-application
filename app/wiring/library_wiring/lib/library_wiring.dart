// The library group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
import 'package:go_router/go_router.dart';
import 'package:library_wiring/src/routes/reading_lists_routes.dart';

export 'package:library_wiring/src/di/di_initializer.dart'
    show LibraryNavigatorsDIInitializer;
export 'package:library_wiring/src/di/library_wiring_di_initializer.dart'
    show LibraryWiringDIInitializer;
export 'package:library_wiring/src/routes/reading_lists_routes.dart'
    show EditReadingListRoute, NewReadingListRoute;
export 'package:library_wiring/src/routes/route_targets.dart'
    show LibraryRouteTargets;

/// The library group's routes (the reading-list editor; collections and
/// offline later).
List<RouteBase> get libraryRoutes => <RouteBase>[...readingListsRoutes];
