import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the hint is not offered
Future<void> theHintIsNotOffered(WidgetTester tester) async {
  await tester.pump();
  expect(find.byKey(playHintKey), findsNothing);
  expect(find.byKey(playPromptKey), findsOneWidget, reason: 'a question');
}
