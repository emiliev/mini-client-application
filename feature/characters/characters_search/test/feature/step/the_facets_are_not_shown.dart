import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: the facets are not shown
///
/// Neither the sort chips nor the team chips are on screen (the recent
/// searches show instead).
Future<void> theFacetsAreNotShown(WidgetTester tester) async {
  expect(find.byKey(searchSortKey), findsNothing);
  expect(find.byKey(searchTeamKey), findsNothing);
}
