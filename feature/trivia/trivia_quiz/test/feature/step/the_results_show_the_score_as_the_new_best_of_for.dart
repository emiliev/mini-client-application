import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the results show the score as the new best of {'characters'} for {'reader@mini-client.test'}
///
/// The backend now holds the shown score as that user's best of the
/// category, and the page says it is a new best.
Future<void> theResultsShowTheScoreAsTheNewBestOfFor(
  WidgetTester tester,
  String category,
  String email,
) async {
  await tester.pump();
  final shown = textOf(tester, resultsScoreKey);
  expect('${(await backendBest(tester, email))[category]}', shown);
  expect(textOf(tester, resultsBestKey), 'Best: $shown');
  expect(find.byKey(resultsNewBestKey), findsOneWidget);
}
