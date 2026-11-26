import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: the fact {'Price'} reads {'$3.99'}
///
/// In the facts section, the row labelled [label] shows exactly [value]
/// (non-breaking spaces read as spaces: intl writes `3,99 $` with one).
Future<void> theFactReads(
  WidgetTester tester,
  String label,
  String value,
) async {
  final facts = find.byKey(comicFactsKey);
  await scrollComicUntilVisible(tester, facts);
  final labelText = find.descendant(of: facts, matching: find.text(label));
  expect(labelText, findsOneWidget, reason: 'one fact is labelled "$label"');
  final row = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  final texts = [
    for (final element in find
        .descendant(of: row, matching: find.byType(Text))
        .evaluate())
      plainSpaces((element.widget as Text).data!),
  ];
  expect(texts, [label, plainSpaces(value)], reason: 'the "$label" fact');
}
