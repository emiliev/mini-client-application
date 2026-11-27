import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: every question showed four choices and a countdown of {20} seconds
///
/// As each question appeared (before any time passed on it).
Future<void> everyQuestionShowedFourChoicesAndACountdownOfSeconds(
  WidgetTester tester,
  int seconds,
) async {
  final shown = shownQuestions();
  expect(shown, hasLength(10));
  for (final q in shown) {
    expect(q.choices, 4, reason: q.prompt);
    expect(q.countdown, secondsLeftLabel(seconds), reason: q.prompt);
  }
}
