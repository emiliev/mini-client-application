import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cast member {'Amber Vanguard'} twice in quick succession
///
/// Two taps on the card within one frame: both reach the card, so both open
/// events reach the bloc.
Future<void> iTapTheCastMemberTwiceInQuickSuccession(
  WidgetTester tester,
  String name,
) => tapComicTarget(tester, castCard(name), times: 2);
