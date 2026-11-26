import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the button {'Remove from favourites'} is disabled
///
/// Exactly one button shows [label], and it does not take taps
/// (`onPressed` is null), so a second tap cannot even reach its bloc.
Future<void> theButtonIsDisabled(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(button, findsOneWidget, reason: 'one button labelled "$label"');
  expect(
    tester.widget<ButtonStyleButton>(button).enabled,
    isFalse,
    reason: '"$label" is disabled',
  );
}
