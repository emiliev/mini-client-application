import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// The index and comic id of the round's first question about a comic.
Future<({int index, int comicId})> firstComicQuestion(
  WidgetTester tester,
) async {
  final questions = questionsOf(await currentRound(tester));
  final index = questions.indexWhere((q) => q['comicId'] != null);
  expect(index, isNonNegative, reason: 'the round has a comic question');
  return (index: index, comicId: questions[index]['comicId']! as int);
}

/// Usage: I tap the comic of the first question about a comic twice in quick succession
///
/// Two taps within one frame on that question's "About this comic".
Future<void> iTapTheComicOfTheFirstQuestionAboutAComicTwiceInQuickSuccession(
  WidgetTester tester,
) async {
  final (:index, comicId: _) = await firstComicQuestion(tester);
  final link = find.byKey(resultsComicKey(index));
  await tester.scrollUntilVisible(
    link,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(resultsBodyKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(link);
  await tester.pumpAndSettle();
  final target = link.hitTestable();
  expect(target, findsOneWidget, reason: 'a tappable comic link');
  await tester.tap(target);
  await tester.tap(target);
  await mcSettle(tester);
}
