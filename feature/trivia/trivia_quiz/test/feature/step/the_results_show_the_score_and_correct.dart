import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the results show the score {150} and {1} correct
Future<void> theResultsShowTheScoreAndCorrect(
  WidgetTester tester,
  int score,
  int correct,
) async {
  await tester.pump();
  expect(textOf(tester, resultsScoreKey), '$score');
  expect(textOf(tester, resultsCorrectKey), '$correct of 10 correct');
}
