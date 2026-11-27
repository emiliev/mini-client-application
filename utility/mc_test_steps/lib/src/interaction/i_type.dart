import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I type {'spi'}
///
/// Replaces the text of the one text field on screen with [text] in one edit
/// (as a paste would), then lets the screen settle: `mcSettle` runs 500 ms
/// of fake time first, so a debounced search fires and is answered.
Future<void> iType(WidgetTester tester, String text) async {
  final field = find.byType(EditableText);
  expect(field, findsOneWidget, reason: 'exactly one text field');
  await tester.enterText(field, text);
  await mcSettle(tester);
}
