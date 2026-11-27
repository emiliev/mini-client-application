import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: reduce motion is {'off'}
///
/// The Reduce motion switch shows `on` or `off`.
Future<void> reduceMotionIs(WidgetTester tester, String onOrOff) async {
  expect(['on', 'off'], contains(onOrOff));
  await tester.pump();
  final row = tester.widget<SwitchListTile>(find.byKey(reduceMotionKey));
  expect(row.value, onOrOff == 'on');
}
