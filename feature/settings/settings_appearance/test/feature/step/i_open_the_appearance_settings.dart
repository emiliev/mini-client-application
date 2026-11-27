import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: I open the appearance settings
///
/// The flow as the app builds it, over the test root (its appearance follows
/// the account in this package), then the screen settles, so a sync that a
/// sign-in started has landed.
Future<void> iOpenTheAppearanceSettings(WidgetTester tester) async {
  await ensureSettingsContainer();
  await initFlow(tester, settingsFlowUnderTest);
  await mcSettle(tester);
  expect(find.byKey(appearanceBodyKey), findsOneWidget);
}
