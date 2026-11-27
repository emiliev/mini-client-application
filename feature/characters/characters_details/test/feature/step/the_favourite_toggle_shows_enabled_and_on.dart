import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the favourite toggle shows {'Remove from favourites'} enabled and on
///
/// Exactly one button shows [label], it takes taps, and a screen reader hears
/// it as a toggle that is on (the `Semantics(toggled:)` around the button).
Future<void> theFavouriteToggleShowsEnabledAndOn(
  WidgetTester tester,
  String label,
) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(button, findsOneWidget, reason: 'one button labelled "$label"');
  expect(tester.widget<ButtonStyleButton>(button).enabled, isTrue);
  final toggles = find.ancestor(
    of: button,
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.toggled != null,
    ),
  );
  expect(
    tester.widget<Semantics>(toggles.first).properties.toggled,
    isTrue,
    reason: 'the toggle is announced as on',
  );
}
