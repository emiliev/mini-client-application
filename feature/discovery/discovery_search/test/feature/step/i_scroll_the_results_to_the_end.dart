import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/discovery_search_env.dart';

/// Usage: I scroll the results to the end
///
/// Rows and notes below the fold are built only once they come near the
/// screen (a lazy list), so a step that looks at the end scrolls there.
Future<void> iScrollTheResultsToTheEnd(WidgetTester tester) async {
  final position = tester.state<ScrollableState>(resultsScrollable()).position;
  position.jumpTo(position.maxScrollExtent);
  await mcSettle(tester);
}
