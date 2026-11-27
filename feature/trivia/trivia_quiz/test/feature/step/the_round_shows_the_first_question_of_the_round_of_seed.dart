import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the round shows the first question of the {'comics'} {'hard'} round of seed {7}
Future<void> theRoundShowsTheFirstQuestionOfTheRoundOfSeed(
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
  await landAtOnce(tester);
  expect(textOf(tester, playPromptKey), questionsOf(round).first['prompt']);
  expect(visibleChoices(), 4);
}
