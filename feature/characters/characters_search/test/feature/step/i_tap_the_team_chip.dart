import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I tap the team chip {'Harbor Watch'}
///
/// Taps the team chip [label], scrolling the chips until it is on screen.
/// Tapping the chosen team again lets every team show.
Future<void> iTapTheTeamChip(WidgetTester tester, String label) =>
    tapChip(tester, searchTeamKey, label);
