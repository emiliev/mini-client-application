import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: no team is chosen
///
/// No team chip is selected: every team shows.
Future<void> noTeamIsChosen(WidgetTester tester) async =>
    expect(selectedChips(tester, searchTeamKey), isEmpty);
