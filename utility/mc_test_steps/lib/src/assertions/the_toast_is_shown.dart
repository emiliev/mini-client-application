import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the toast {'Comic saved'} is shown
///
/// Exactly one toast is up, and it says [text]. A replaced or expired toast
/// is not shown.
Future<void> theToastIsShown(WidgetTester tester, String text) async {
  expect(find.byType(SnackBar), findsOneWidget, reason: 'one toast is shown');
  expect(
    find.descendant(of: find.byType(SnackBar), matching: find.text(text)),
    findsOneWidget,
    reason: 'the toast says "$text"',
  );
}
