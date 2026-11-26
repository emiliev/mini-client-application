import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the visibility is {'Public'}
///
/// The segment with that label is the selected one.
Future<void> theVisibilityIs(WidgetTester tester, String label) async {
  final segment = find.descendant(
    of: find.byKey(visibilityKey),
    matching: find.bySemanticsLabel(label),
  );
  expect(segment, findsOneWidget, reason: 'a segment "$label"');
  expect(
    tester.getSemantics(segment).flagsCollection.isSelected,
    Tristate.isTrue,
    reason: '"$label" is selected',
  );
}
