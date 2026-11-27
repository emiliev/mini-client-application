import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: I tap the comic {'Brass Crossing #8'} and then {'Cinder Reckoning #2'} after {450} milliseconds
///
/// Taps one card, then another card [milliseconds] of fake time later: two
/// different targets, not a double tap.
Future<void> iTapTheComicAndThenAfterMilliseconds(
  WidgetTester tester,
  String first,
  String second,
  int milliseconds,
) async {
  // Both cards on screen first: scrolling and settling would spend the time
  // this step measures.
  await scrollCharacterUntilVisible(tester, find.byKey(characterComicsKey));
  expect(comicCard(first).hitTestable(), findsOneWidget);
  expect(comicCard(second).hitTestable(), findsOneWidget);
  await tester.tap(comicCard(first).hitTestable());
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.tap(comicCard(second).hitTestable());
  await mcSettle(tester);
}
