import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: the results show the first {30} characters for {'spi'} of team {'Harbor Watch'}
///
/// The list shows the first [count] matches of [prefix] of [team], in name order, top to bottom,
/// each with its name and its bundled art. Rows below the fold are read by
/// scrolling, which may load the next page; with every match counted the
/// list is read to its end.
Future<void> theResultsShowTheFirstCharactersForOfTeam(
  WidgetTester tester,
  int count,
  String prefix,
  String team,
) => expectResults(tester, prefix: prefix, count: count, team: team);
