import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the density is {'Comfortable'}
///
/// The density control's selected segment has this label.
Future<void> theDensityIs(WidgetTester tester, String label) async {
  await tester.pump();
  expect(selectedLabel(tester, densityKey('comfortable')), label);
}
