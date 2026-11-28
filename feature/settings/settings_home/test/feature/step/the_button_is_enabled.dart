import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the button {'Sign in'} is enabled
///
/// Exactly one button shows [label], and it takes taps (`onPressed` is set).
Future<void> theButtonIsEnabled(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(button, findsOneWidget, reason: 'one button labelled "$label"');
  expect(
    tester.widget<ButtonStyleButton>(button).enabled,
    isTrue,
    reason: '"$label" is enabled',
  );
}
