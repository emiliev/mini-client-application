import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:publishing_wiring/src/routes/route_targets.dart';

part 'comics_routes.g.dart';

/// The publishing group's comic routes (generated `$appRoutes`).
List<RouteBase> get comicsRoutes => $appRoutes;

/// `/comics/:id`: one comic. The flow starts from the id alone, so a deep
/// link (`miniclient://app/comics/501500`) opens it directly. The app shell
/// nests it under home (T-0049), so a cold link has a back button.
@TypedGoRoute<ComicDetailsRoute>(path: '/comics/:id')
class ComicDetailsRoute extends GoRouteData with $ComicDetailsRoute {
  const ComicDetailsRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<PublishingRouteTargets>().comicDetails(id);
}
