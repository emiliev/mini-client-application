import 'package:flutter_test/flutter_test.dart';

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
  await tapComicTarget(tester, castCard(first));
  await tester.pump(Duration(milliseconds: milliseconds));
  await tapComicTarget(tester, castCard(second));
}
