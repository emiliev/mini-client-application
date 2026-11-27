import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: I open character {501500}
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator passed in the constructor [tide-nav §3.1].
Future<void> iOpenCharacter(WidgetTester tester, int id) async {
  await ensureCharactersContainer();
  await initFlow(
    tester,
    () => charactersTestHost(characterDetailsFlowUnderTest(id)),
  );
  await mcSettle(tester);
}
