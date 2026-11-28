import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: the sort {'Name A–Z'} is chosen
///
/// Exactly the sort chip [label] is selected.
Future<void> theSortIsChosen(WidgetTester tester, String label) async =>
    expect(selectedChips(tester, searchSortKey), [label]);
