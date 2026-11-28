import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_search_env.dart';

/// Usage: I scroll the results to the end
///
/// Scrolls the list to its end and on while pages keep loading, until the
/// last page arrived or a later page failed (its footer offers Retry).
Future<void> iScrollTheResultsToTheEnd(WidgetTester tester) async {
  await shownResults(tester);
  final position = resultsPosition(tester);
  position.jumpTo(position.maxScrollExtent);
  await mcSettle(tester);
}
