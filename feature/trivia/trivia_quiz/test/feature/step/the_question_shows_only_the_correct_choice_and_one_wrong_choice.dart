import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the question shows only the correct choice and one wrong choice
///
/// The 50/50 hint hid two of the three wrong choices.
Future<void> theQuestionShowsOnlyTheCorrectChoiceAndOneWrongChoice(
  WidgetTester tester,
) async {
  await tester.pump();
  final question = shownQuestion(tester, await currentRound(tester));
  expect(visibleChoices(), 2);
  expect(
    find.byKey(playChoiceKey(question['correctChoiceId']! as String)),
    findsOneWidget,
  );
}
