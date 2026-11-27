import 'package:chronicle_wiring/src/routes/route_targets.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

part 'trivia_routes.g.dart';

/// The chronicle group's trivia routes (generated `$appRoutes`).
List<RouteBase> get triviaRoutes => $appRoutes;

/// `/trivia`: the quiz's setup. A round nests under it, so a deep link to a
/// round (`miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42`)
/// opens `[home, trivia, round]` (the app shell nests `/trivia` under home,
/// T-0049) and Back walks that path. Route names are the screens analytics
/// tracks (T-0053); the flows' first pages carry the same names (ADR-0012).
@TypedGoRoute<TriviaRoute>(
  path: '/trivia',
  name: 'trivia_setup',
  routes: [TypedGoRoute<TriviaPlayRoute>(path: 'play', name: 'trivia_play')],
)
class TriviaRoute extends GoRouteData with $TriviaRoute {
  const TriviaRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<ChronicleRouteTargets>().trivia();
}

/// `/trivia/play?category=&difficulty=&seed=`: the quiz opened at a round.
class TriviaPlayRoute extends GoRouteData with $TriviaPlayRoute {
  const TriviaPlayRoute({this.category, this.difficulty, this.seed});

  final String? category;
  final String? difficulty;
  final int? seed;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      diContainer<ChronicleRouteTargets>().triviaRound(
        category: category,
        difficulty: difficulty,
        seed: seed,
      );
}
