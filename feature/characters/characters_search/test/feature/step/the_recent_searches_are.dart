import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: the recent searches are {'spi, amber'}
///
/// The recent searches show, exactly these, most recent first.
Future<void> theRecentSearchesAre(WidgetTester tester, String queries) async =>
    expect(shownHistory(tester), listArgument(queries));
