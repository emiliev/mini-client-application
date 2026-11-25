import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I open the characters list
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator passed in the constructor [tide-nav §3.1].
Future<void> iOpenTheCharactersList(WidgetTester tester) async {
  await initFlow(
    tester,
    () => charactersTestHost(charactersListFlowUnderTest()),
  );
  await mcSettle(tester);
}
