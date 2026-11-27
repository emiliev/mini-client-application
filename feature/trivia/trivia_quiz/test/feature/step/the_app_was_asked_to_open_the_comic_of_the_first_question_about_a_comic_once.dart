import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';
import 'i_tap_the_comic_of_the_first_question_about_a_comic_twice_in_quick_succession.dart';

/// Usage: the app was asked to open the comic of the first question about a comic once
///
/// `openComic` was called exactly once, with that question's comic id, and
/// nothing else was handed over.
Future<void> theAppWasAskedToOpenTheComicOfTheFirstQuestionAboutAComicOnce(
  WidgetTester tester,
) async {
  final (index: _, :comicId) = await firstComicQuestion(tester);
  expect(navigatorCalls(), ['comic $comicId']);
}
