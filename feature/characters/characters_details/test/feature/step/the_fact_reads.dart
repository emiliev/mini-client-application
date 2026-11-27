import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: the fact {'Origin'} reads {'an archivist of lost maps'}
///
/// In the facts section, the row labelled [label] shows exactly [value].
Future<void> theFactReads(
  WidgetTester tester,
  String label,
  String value,
) async {
  final facts = find.byKey(characterFactsKey);
  await scrollCharacterUntilVisible(tester, facts);
  final labelText = find.descendant(of: facts, matching: find.text(label));
  expect(labelText, findsOneWidget, reason: 'one fact is labelled "$label"');
  final row = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  final texts = [
    for (final element
        in find.descendant(of: row, matching: find.byType(Text)).evaluate())
      (element.widget as Text).data!,
  ];
  expect(texts, [label, value], reason: 'the "$label" fact');
}
