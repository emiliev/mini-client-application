import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the question is open with {15} seconds left
///
/// Not answered or timed out yet, and the countdown says [seconds] left
/// (rounded up), checked through its accessible label.
Future<void> theQuestionIsOpenWithSecondsLeft(
  WidgetTester tester,
  int seconds,
) async {
  await tester.pump();
  expect(find.byKey(playNextKey), findsNothing, reason: 'still open');
  expect(countdownLabel(tester), secondsLeftLabel(seconds));
}
