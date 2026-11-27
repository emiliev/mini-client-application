import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the countdown is a ring around the number
Future<void> theCountdownIsARingAroundTheNumber(WidgetTester tester) async {
  await tester.pump();
  expect(
    find.descendant(
      of: find.byKey(countdownRingKey),
      matching: find.byKey(countdownNumberKey),
    ),
    findsOneWidget,
  );
}
