import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the question shows four choices
Future<void> theQuestionShowsFourChoices(WidgetTester tester) async {
  await tester.pump();
  expect(visibleChoices(), 4);
}
