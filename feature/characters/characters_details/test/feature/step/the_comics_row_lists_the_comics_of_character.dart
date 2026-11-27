import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: the comics row lists the comics of character {100002}
///
/// The row holds exactly the comics that feature the fixture character, in
/// the comics domain's title order, each as a media card with the comic's
/// title and the bundled asset of its cover. The row is lazy like any list,
/// so the step drags it to its end and collects each card as it is built.
Future<void> theComicsRowListsTheComicsOfCharacter(
  WidgetTester tester,
  int id,
) async {
  final expected = comicsOf(id);
  expect(expected, isNotEmpty, reason: 'the fixture character has comics');
  final row = find.byKey(characterComicsKey);
  await scrollCharacterUntilVisible(tester, row);
  final rowScrollable = find
      .descendant(of: row, matching: find.byType(Scrollable))
      .first;

  final titles = <String>[];
  void collect() {
    final cards = find.descendant(of: row, matching: find.byType(McMediaCard));
    for (final (i, element) in cards.evaluate().indexed) {
      final card = element.widget as McMediaCard;
      if (titles.contains(card.title)) {
        continue;
      }
      titles.add(card.title!);
      final record = expected[titles.length - 1];
      expect(card.title, record.title, reason: 'card ${titles.length} title');
      expect(card.image, record.cover, reason: '${card.title} art');
      final image = find.descendant(
        of: cards.at(i),
        matching: find.byType(Image),
      );
      expect(
        tester.widget<Image>(image).image,
        bundledArtFor(record.cover),
        reason: '${card.title} draws its bundled asset',
      );
    }
  }

  collect();
  for (var drags = 0; drags < 50; drags++) {
    final position = tester.state<ScrollableState>(rowScrollable).position;
    if (position.pixels >= position.maxScrollExtent) {
      break;
    }
    await tester.drag(rowScrollable, const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    collect();
  }
  await mcSettle(tester);

  expect(titles, [
    for (final comic in expected) comic.title,
  ], reason: 'the comics of character $id, in order');
}
