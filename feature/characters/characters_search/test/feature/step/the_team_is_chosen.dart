import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: the team {'Harbor Watch'} is chosen
///
/// Exactly the team chip [label] is selected.
Future<void> theTeamIsChosen(WidgetTester tester, String label) async =>
    expect(selectedChips(tester, searchTeamKey), [label]);
