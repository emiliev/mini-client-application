import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/store_home_env.dart';

/// Usage: I open the store
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator and the clock passed in the constructor.
Future<void> iOpenTheStore(WidgetTester tester) async {
  await ensureStoreContainer();
  await initFlow(tester, () => storeTestHost(storeFlowUnderTest()));
  await mcSettle(tester);
}
