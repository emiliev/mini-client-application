// One typed route file over real go_router 17.5.0 in a Flutter closure
// (T-0014-AC7, V3-01). go_router_builder writes `routes.g.dart`.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:hello/src/pages.dart';

part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [TypedGoRoute<DetailRoute>(path: 'detail/:count')],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      HomePage(onOpenDetail: (count) => DetailRoute(count: count).go(context));
}

class DetailRoute extends GoRouteData with $DetailRoute {
  const DetailRoute({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DetailPage(count: count);
}

/// The app's router, built from the generated `$appRoutes`.
GoRouter buildRouter() => GoRouter(routes: $appRoutes);
