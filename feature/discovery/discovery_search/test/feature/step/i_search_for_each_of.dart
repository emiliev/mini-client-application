import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

import '../util/discovery_search_env.dart';

/// Usage: I search for each of {'spi, amber, chron'}
///
/// Types each query in turn (`I type`), letting each search be answered
/// before the next.
Future<void> iSearchForEachOf(WidgetTester tester, String queries) async {
  for (final query in listArgument(queries)) {
    await iType(tester, query);
  }
}
