import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';

part 'characters_routes.g.dart';

/// The universe group's character routes (generated `$appRoutes`).
List<RouteBase> get charactersRoutes => $appRoutes;

/// `/characters`: the characters list. Details and the search nest under it,
/// so a deep link to a character, or to the search, builds the back stack
/// list -> details (or list -> search). The search comes first: `search` is
/// a fixed segment and `:id` would otherwise take it.
@TypedGoRoute<CharactersRoute>(
  path: '/characters',
  name: 'characters_list',
  routes: [
    TypedGoRoute<CharactersSearchRoute>(
      path: 'search',
      name: 'characters_search',
    ),
    TypedGoRoute<CharacterDetailsRoute>(path: ':id', name: 'character_details'),
  ],
)
class CharactersRoute extends GoRouteData with $CharactersRoute {
  const CharactersRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<UniverseRouteTargets>().characters();
}

/// `/characters/search`: the character search, optionally starting with a
/// query (`miniclient://app/characters/search?q=a`; T-0071). Its name is the
/// screen the flow tracks (`characters_search`).
class CharactersSearchRoute extends GoRouteData with $CharactersSearchRoute {
  const CharactersSearchRoute({this.q});

  /// The query to start with; null opens on the recent searches.
  final String? q;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<UniverseRouteTargets>().charactersSearch(query: q);
}

/// `/characters/:id`: the character's profile.
class CharacterDetailsRoute extends GoRouteData with $CharacterDetailsRoute {
  const CharacterDetailsRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<UniverseRouteTargets>().characterDetails(id);
}
