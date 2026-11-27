import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the countdown shows it is paused
Future<void> theCountdownShowsItIsPaused(WidgetTester tester) async {
  await tester.pump();
  expect(textOf(tester, countdownNumberKey), 'Paused');
}
