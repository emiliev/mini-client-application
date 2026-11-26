import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:publishing_wiring/src/routes/route_targets.dart';

part 'creators_routes.g.dart';

/// The publishing group's creator routes (generated `$appRoutes`).
List<RouteBase> get creatorsRoutes => $appRoutes;

/// `/creators/:id`: one creator (a placeholder for now).
@TypedGoRoute<CreatorDetailsRoute>(path: '/creators/:id')
class CreatorDetailsRoute extends GoRouteData with $CreatorDetailsRoute {
  const CreatorDetailsRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<PublishingRouteTargets>().creatorDetails(id);
}
