import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the results show only the characters section
Future<void> theResultsShowOnlyTheCharactersSection(
  WidgetTester tester,
) async {
  final rows = await shownResults(tester);
  expect(shownSections(tester), ['character']);
  expect({for (final row in rows) row.type}, {'character'});
}
