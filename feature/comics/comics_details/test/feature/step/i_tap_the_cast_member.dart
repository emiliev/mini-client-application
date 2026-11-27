import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cast member {'Amber Vanguard'}
///
/// Scrolls the cast row into view, then taps that character's card.
Future<void> iTapTheCastMember(WidgetTester tester, String name) =>
    tapComicTarget(tester, castCard(name));
