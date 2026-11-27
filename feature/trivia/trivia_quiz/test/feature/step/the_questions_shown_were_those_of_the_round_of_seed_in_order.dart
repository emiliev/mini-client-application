import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the questions shown were those of the {'characters'} {'easy'} round of seed {42} in order
///
/// The ten prompts shown, one after the other, are the fixture round's.
Future<void> theQuestionsShownWereThoseOfTheRoundOfSeedInOrder(
  WidgetTester tester,
  String category,
  String difficulty,
  int seed,
) async {
  final round = await fixtureRound(
    tester,
    category: category,
    difficulty: difficulty,
    seed: seed,
  );
  expect(
    [for (final q in shownQuestions()) q.prompt],
    [for (final q in questionsOf(round)) q['prompt']],
  );
}
