import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the results show only the comics section
Future<void> theResultsShowOnlyTheComicsSection(WidgetTester tester) async {
  final rows = await shownResults(tester);
  expect(shownSections(tester), ['comic']);
  expect({for (final row in rows) row.type}, {'comic'});
}
