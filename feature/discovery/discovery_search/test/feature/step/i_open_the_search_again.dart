import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I open the search again
///
/// Closes the open search flow (its scope, bloc and history instance go
/// away) and opens a new one over the same app root and storage, as leaving
/// the search and coming back does.
Future<void> iOpenTheSearchAgain(WidgetTester tester) => openSearch(tester);
