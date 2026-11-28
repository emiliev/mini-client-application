import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/settings_home_env.dart';

/// Usage: the row {'appearance'} reads {'Dark'}
///
/// The subtitle of the list tile keyed `settings_home.<name>`
/// (`appearance`, `about.version`, `about.seed`) is exactly [text].
Future<void> theRowReads(WidgetTester tester, String name, String text) async {
  final row = find.byKey(rowKey(name));
  expect(row, findsOneWidget, reason: 'the "$name" row');
  final subtitle = tester.widget<ListTile>(row).subtitle;
  expect(subtitle, isA<Text>(), reason: 'the "$name" row has a subtitle');
  expect((subtitle! as Text).data, text, reason: 'the "$name" row');
}
