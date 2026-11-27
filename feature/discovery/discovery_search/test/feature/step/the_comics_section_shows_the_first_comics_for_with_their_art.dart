import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the comics section shows the first {5} comics for {'spi'} with their art
///
/// The rows are the fixture index's first [count] ranked comics for [query],
/// in order, each with its title, year and bundled cover.
Future<void> theComicsSectionShowsTheFirstComicsForWithTheirArt(
  WidgetTester tester,
  int count,
  String query,
) => expectSectionShows(tester, type: 'comic', count: count, query: query);
