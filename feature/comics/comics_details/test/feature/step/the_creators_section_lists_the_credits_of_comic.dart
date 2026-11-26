import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: the creators section lists the credits of comic {501500}
///
/// Below its title, the section shows exactly the fixture's credits, in the
/// contract's role order: each creator's name, then the role in English.
Future<void> theCreatorsSectionListsTheCreditsOfComic(
  WidgetTester tester,
  int id,
) async {
  final record = comicRecord(id);
  await scrollComicUntilVisible(tester, find.text('Creators'));
  final section = find.byKey(comicCreditsKey);
  await scrollComicUntilVisible(tester, section);
  // Bring the whole section on screen, so every row is built.
  await scrollComicUntilVisible(
    tester,
    find.descendant(
      of: section,
      matching: find.text(record.creators.last.name),
    ),
  );

  final texts = [
    for (final element
        in find.descendant(of: section, matching: find.byType(Text)).evaluate())
      (element.widget as Text).data,
  ];
  expect(texts, [
    for (final credit in record.creators) ...[
      credit.name,
      englishRoles[credit.role],
    ],
  ], reason: 'the credits of ${record.title}, in order');
}
