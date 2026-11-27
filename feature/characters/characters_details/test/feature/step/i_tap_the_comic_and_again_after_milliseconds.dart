import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: I tap the comic {'Brass Crossing #8'} and again after {499} milliseconds
///
/// Two taps on the card, [milliseconds] of fake time apart.
Future<void> iTapTheComicAndAgainAfterMilliseconds(
  WidgetTester tester,
  String title,
  int milliseconds,
) => tapCharacterTarget(
  tester,
  comicCard(title),
  times: 2,
  between: Duration(milliseconds: milliseconds),
);
