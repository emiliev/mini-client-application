import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: I open the settings
///
/// The flow as the app builds it, over the test root, then the screen
/// settles, so the profile read a signed-in user starts has landed (unless
/// the scenario holds it).
Future<void> iOpenTheSettings(WidgetTester tester) async {
  await ensureSettingsContainer();
  await initFlow(tester, settingsFlowUnderTest);
  await mcSettle(tester);
  expect(find.byKey(settingsBodyKey), findsOneWidget);
}
