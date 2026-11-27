import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the theme mode is {'System'}
///
/// The theme control's selected segment has this label (in the running
/// locale).
Future<void> theThemeModeIs(WidgetTester tester, String label) async {
  await tester.pump();
  expect(selectedLabel(tester, themeModeKey('system')), label);
}
