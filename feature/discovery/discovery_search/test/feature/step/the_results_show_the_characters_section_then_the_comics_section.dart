import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the results show the characters section, then the comics section
///
/// Both sections show, characters above comics (the contract's group
/// order), and every character row comes before every comic row.
Future<void> theResultsShowTheCharactersSectionThenTheComicsSection(
  WidgetTester tester,
) async {
  final rows = await shownResults(tester);
  expect(shownSections(tester), ['character', 'comic']);
  final types = [for (final row in rows) row.type];
  expect(types, contains('character'));
  expect(types, contains('comic'));
  expect(
    types.lastIndexOf('character'),
    lessThan(types.indexOf('comic')),
    reason: 'every character row is above every comic row: $types',
  );
}
