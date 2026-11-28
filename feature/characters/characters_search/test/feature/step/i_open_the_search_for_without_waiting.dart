import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I open the search for {'spi'} without waiting
///
/// Opens the flow with an initial query and draws one frame: no fake time
/// passes (a debounce would not have fired) and no real storage I/O
/// completes (the recent searches are still being read).
Future<void> iOpenTheSearchForWithoutWaiting(
  WidgetTester tester,
  String query,
) => openSearch(tester, initialQuery: query, wait: false);
