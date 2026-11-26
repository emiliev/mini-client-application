import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';

part 'characters_routes.g.dart';

/// The universe group's character routes (generated `$appRoutes`).
List<RouteBase> get charactersRoutes => $appRoutes;

/// `/characters`: the characters list. Details nest under it, so a deep link
/// to a character builds the back stack list -> details.
@TypedGoRoute<CharactersRoute>(
  path: '/characters',
  routes: [TypedGoRoute<CharacterDetailsRoute>(path: ':id')],
)
class CharactersRoute extends GoRouteData with $CharactersRoute {
  const CharactersRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<RouteTargets>().characters();
}

/// `/characters/:id`: the character's details (a placeholder for now).
class CharacterDetailsRoute extends GoRouteData with $CharacterDetailsRoute {
  const CharacterDetailsRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<RouteTargets>().characterDetails(id);
}
