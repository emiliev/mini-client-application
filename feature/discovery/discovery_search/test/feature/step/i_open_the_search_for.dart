import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I open the search for {'spi'}
///
/// Opens the flow with an initial query, as the route `/search?q=spi` does,
/// and lets it settle (the debounce fires within the step).
Future<void> iOpenTheSearchFor(WidgetTester tester, String query) =>
    openSearch(tester, initialQuery: query);
