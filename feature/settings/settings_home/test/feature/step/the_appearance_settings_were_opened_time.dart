import 'package:flutter_test/flutter_test.dart';

import '../util/settings_home_env.dart';

/// Usage: the appearance settings were opened {1} time
///
/// `openAppearance()` was called exactly [count] times in all (0: never).
Future<void> theAppearanceSettingsWereOpenedTime(
  WidgetTester tester,
  int count,
) async {
  expect(appearanceRequests(), count);
}
