import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_search_env.dart';

/// Usage: I scroll the results until the next page loads
///
/// Jumps to the end of what is loaded once and lets the answer arrive: the
/// list asks for exactly the next page.
Future<void> iScrollTheResultsUntilTheNextPageLoads(WidgetTester tester) async {
  final position = resultsPosition(tester);
  position.jumpTo(position.maxScrollExtent);
  await mcSettle(tester);
}
