import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I open the round {'all'} {'easy'} of seed {42}
///
/// Enters the flow at a round, as `/trivia/play?category=&difficulty=&seed=`
/// does. Nothing moves fake time: the first question's clock starts at 0 and
/// the next step decides how long it is open.
Future<void> iOpenTheRoundOfSeed(
  WidgetTester tester,
  String category,
  String difficulty,
  int seed,
) async {
  currentSpec = (category: category, difficulty: difficulty, seed: seed);
  // Read the fixture round first: it needs real async, which must not run
  // once the question's clock is going.
  await currentRound(tester);
  await ensureTriviaContainer();
  await initFlow(
    tester,
    () => triviaTestHost(
      triviaFlowUnderTest(
        category: category,
        difficulty: difficulty,
        seed: seed,
      ),
    ),
  );
  await landAtOnce(tester);
}
