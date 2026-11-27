import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cast member {'Amber Vanguard'} and then {'Prism Engineer'} after {450} milliseconds
///
/// Taps one card, then another card [milliseconds] of fake time later: two
/// different targets, not a double tap.
Future<void> iTapTheCastMemberAndThenAfterMilliseconds(
  WidgetTester tester,
  String first,
  String second,
  int milliseconds,
) async {
  // Both cards on screen first: scrolling and settling would spend the time
  // this step measures.
  await scrollComicUntilVisible(tester, castCard(first));
  await scrollComicUntilVisible(tester, castCard(second));
  await scrollComicUntilVisible(tester, castCard(first));
  expect(castCard(first).hitTestable(), findsOneWidget);
  expect(castCard(second).hitTestable(), findsOneWidget);
  await tester.tap(castCard(first).hitTestable());
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.tap(castCard(second).hitTestable());
  await mcSettle(tester);
}
