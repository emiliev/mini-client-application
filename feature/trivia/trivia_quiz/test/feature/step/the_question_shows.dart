import 'package:flutter_test/flutter_test.dart';

/// Usage: the question shows {'Correct! +150'}
Future<void> theQuestionShows(WidgetTester tester, String text) async {
  await tester.pump();
  expect(find.textContaining(text), findsWidgets, reason: '"$text"');
}
