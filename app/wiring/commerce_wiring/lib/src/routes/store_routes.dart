import 'package:commerce_wiring/src/routes/route_targets.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'store_routes.g.dart';

/// The commerce group's store routes (generated `$appRoutes`).
List<RouteBase> get storeRoutes => $appRoutes;

/// `/store`: the store home. Its children nest under it, so a deep link to a
/// category (`miniclient://app/store/categories/heroes`) opens
/// `[home, store, category]` (the app shell nests `/store` under home,
/// T-0049) and Back walks that path. Route names are the screens analytics
/// tracks (T-0053); the flow's own pages carry the same names (F-0056).
@TypedGoRoute<StoreRoute>(
  path: '/store',
  name: 'store_home',
  routes: [
    TypedGoRoute<StoreCategoryRoute>(
      path: 'categories/:id',
      name: 'store_category',
    ),
    TypedGoRoute<StoreCartRoute>(path: 'cart', name: 'store_cart'),
  ],
)
class StoreRoute extends GoRouteData with $StoreRoute {
  const StoreRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<CommerceRouteTargets>().store();
}

/// `/store/categories/:id`: the store flow opened at one category.
class StoreCategoryRoute extends GoRouteData with $StoreCategoryRoute {
  const StoreCategoryRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<CommerceRouteTargets>().store(category: id);
}

/// `/store/cart`: the cart (a placeholder for now).
class StoreCartRoute extends GoRouteData with $StoreCartRoute {
  const StoreCartRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<CommerceRouteTargets>().cart();
}
