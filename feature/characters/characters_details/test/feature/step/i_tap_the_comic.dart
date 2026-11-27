import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: I tap the comic {'Brass Crossing #8'}
///
/// Scrolls the comics row into view, then taps that comic's card.
Future<void> iTapTheComic(WidgetTester tester, String title) =>
    tapCharacterTarget(tester, comicCard(title));
