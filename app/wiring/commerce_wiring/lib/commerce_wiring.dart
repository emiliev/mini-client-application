// The commerce group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
// Checkout and orders join with their features.
import 'package:commerce_wiring/src/routes/store_routes.dart';
import 'package:go_router/go_router.dart';

export 'package:commerce_wiring/src/di/commerce_wiring_di_initializer.dart'
    show CommerceWiringDIInitializer, commerceClock;
export 'package:commerce_wiring/src/di/di_initializer.dart'
    show CommerceNavigatorsDIInitializer;
export 'package:commerce_wiring/src/flows/cart_placeholder_flow.dart'
    show CartPlaceholderFlow;
export 'package:commerce_wiring/src/routes/route_targets.dart'
    show CommerceRouteTargets;
export 'package:commerce_wiring/src/routes/store_routes.dart'
    show StoreCartRoute, StoreCategoryRoute, StoreRoute;

/// The commerce group's routes (the store; checkout later).
List<RouteBase> get commerceRoutes => <RouteBase>[...storeRoutes];
