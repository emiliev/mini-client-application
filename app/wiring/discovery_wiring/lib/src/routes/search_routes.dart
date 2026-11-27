import 'package:discovery_wiring/src/routes/route_targets.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'search_routes.g.dart';

/// The discovery group's search routes (generated `$appRoutes`).
List<RouteBase> get searchRoutes => $appRoutes;

/// `/search`: the search, optionally starting with a query
/// (`miniclient://app/search?q=spi`). The app shell nests it under home
/// (T-0049), so a deep link opens `[home, search]`.
@TypedGoRoute<SearchRoute>(path: '/search')
class SearchRoute extends GoRouteData with $SearchRoute {
  const SearchRoute({this.q});

  /// The query to start with; null opens on the recent searches.
  final String? q;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<DiscoveryRouteTargets>().search(query: q);
}
