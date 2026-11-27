import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the question timed out
Future<void> theQuestionTimedOut(WidgetTester tester) async {
  await tester.pump();
  expect(find.byKey(playNextKey), findsOneWidget, reason: 'it is over');
  expect(find.textContaining("Time's up"), findsOneWidget);
  expect(countdownLabel(tester), secondsLeftLabel(0));
}
