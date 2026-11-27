import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: I tap the comic {'Brass Crossing #8'} twice in quick succession
///
/// Two taps on the card within one frame: both reach the card, so both open
/// events reach the bloc.
Future<void> iTapTheComicTwiceInQuickSuccession(
  WidgetTester tester,
  String title,
) => tapCharacterTarget(tester, comicCard(title), times: 2);
