import 'package:chronicle_wiring/src/routes/route_targets.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class ChronicleRouteTargetsImpl implements ChronicleRouteTargets {
  const ChronicleRouteTargetsImpl({
    required TriviaQuizNavigator trivia,
    required int Function() clock,
    required int Function() nextSeed,
  }) : _trivia = trivia,
       _clock = clock,
       _nextSeed = nextSeed;

  final TriviaQuizNavigator _trivia;
  final int Function() _clock;
  final int Function() _nextSeed;

  @override
  TriviaQuizFlow trivia() =>
      TriviaQuizFlow(navigator: _trivia, clock: _clock, nextSeed: _nextSeed);

  @override
  TriviaQuizFlow triviaRound({
    String? category,
    String? difficulty,
    int? seed,
  }) => TriviaQuizFlow(
    navigator: _trivia,
    clock: _clock,
    nextSeed: _nextSeed,
    category: category ?? 'all',
    difficulty: difficulty ?? 'easy',
    seed: seed,
  );
}
