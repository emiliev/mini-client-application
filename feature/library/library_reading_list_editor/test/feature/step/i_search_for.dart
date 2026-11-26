import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:flutter/material.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I search for {'Amber Chr'}
///
/// Types into the comic search field; the step ends when the debounced
/// search settled.
Future<void> iSearchFor(WidgetTester tester, String query) async {
  final field = find.byType(TextField).hitTestable();
  expect(field, findsOneWidget, reason: 'step 2 has one text field');
  await tester.enterText(field, query);
  await mcSettle(tester);
}
