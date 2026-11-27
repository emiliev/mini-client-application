import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: I switch reduce motion {'on'}
///
/// Taps the Reduce motion row; fails if it already shows that value (the
/// tap would switch it the other way).
Future<void> iSwitchReduceMotion(WidgetTester tester, String onOrOff) async {
  expect(['on', 'off'], contains(onOrOff));
  final row = find.byKey(reduceMotionKey);
  await scrollSettingsTo(tester, row);
  expect(
    tester.widget<SwitchListTile>(row).value,
    onOrOff != 'on',
    reason: 'reduce motion is not $onOrOff yet',
  );
  await tester.tap(row);
  await mcSettle(tester);
}
