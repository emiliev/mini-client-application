import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the countdown is the number only
Future<void> theCountdownIsTheNumberOnly(WidgetTester tester) async {
  await tester.pump();
  expect(find.byKey(countdownNumberKey), findsOneWidget);
  expect(find.byKey(countdownRingKey), findsNothing);
}
