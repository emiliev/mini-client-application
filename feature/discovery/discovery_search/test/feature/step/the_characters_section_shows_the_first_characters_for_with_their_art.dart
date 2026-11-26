import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the characters section shows the first {5} characters for {'spi'} with their art
///
/// The rows are the fixture index's first [count] ranked characters for
/// [query], in order, each with its title, team and bundled art.
Future<void> theCharactersSectionShowsTheFirstCharactersForWithTheirArt(
  WidgetTester tester,
  int count,
  String query,
) => expectSectionShows(
  tester,
  type: 'character',
  count: count,
  query: query,
);
