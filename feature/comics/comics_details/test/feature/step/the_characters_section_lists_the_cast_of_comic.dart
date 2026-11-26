import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';

import '../util/comics_details_env.dart';

/// Usage: the characters section lists the cast of comic {501500}
///
/// The cast row holds exactly the fixture comic's characters, in its
/// `characterIds` order, each as a media card with the character's name (from
/// the characters fixture) and the bundled asset of its thumbnail.
Future<void> theCharactersSectionListsTheCastOfComic(
  WidgetTester tester,
  int id,
) async {
  final record = comicRecord(id);
  final row = find.byKey(comicCastKey);
  await scrollComicUntilVisible(tester, row);
  final expected = [for (final c in record.characterIds) characterWithId(c)];

  final cards = find.descendant(of: row, matching: find.byType(McMediaCard));
  final shown = [
    for (final element in cards.evaluate()) element.widget as McMediaCard,
  ];
  expect(
    [for (final card in shown) card.title],
    [for (final c in expected) c.name],
    reason: 'the cast of ${record.title}, in order',
  );
  for (final (i, card) in shown.indexed) {
    expect(card.image, expected[i].thumbnail, reason: '${card.title} art');
    final image = find.descendant(
      of: cards.at(i),
      matching: find.byType(Image),
    );
    expect(
      tester.widget<Image>(image).image,
      bundledArtFor(expected[i].thumbnail),
      reason: '${card.title} draws its bundled asset',
    );
  }
}
