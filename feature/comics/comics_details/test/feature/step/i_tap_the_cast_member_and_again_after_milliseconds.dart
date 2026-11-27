import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cast member {'Amber Vanguard'} and again after {499} milliseconds
///
/// Two taps on the card, [milliseconds] of fake time apart.
Future<void> iTapTheCastMemberAndAgainAfterMilliseconds(
  WidgetTester tester,
  String name,
  int milliseconds,
) => tapComicTarget(
  tester,
  castCard(name),
  times: 2,
  between: Duration(milliseconds: milliseconds),
);
