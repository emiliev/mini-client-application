import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I open the search
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator passed in the constructor [tide-nav §3.1]. The flow
/// reads the recent searches from storage before the step ends.
Future<void> iOpenTheSearch(WidgetTester tester) => openSearch(tester);
