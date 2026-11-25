import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';

import '../util/characters_list_env.dart';

/// Usage: I see the first {30} characters in name order with their bundled art
///
/// The grid holds exactly [count] characters, and walking it with real drags
/// shows them as media cards in the fixture's name order, each drawing the
/// bundled asset of its own thumbnail (not the fallback).
Future<void> iSeeTheFirstCharactersInNameOrderWithTheirBundledArt(
  WidgetTester tester,
  int count,
) async {
  expect(charactersShown(tester), count, reason: 'the grid holds one page');
  final expected = defaultCast.take(count).toList();
  final seen = <String>[];
  for (var drags = 0; seen.length < count; drags++) {
    if (drags > 100) {
      fail('saw ${seen.length} of $count characters after 100 drags: $seen');
    }
    final cards = find.descendant(
      of: find.byKey(charactersGridKey),
      matching: find.byType(McMediaCard),
    );
    for (final element in cards.evaluate()) {
      final card = element.widget as McMediaCard;
      if (seen.contains(card.title) || seen.length >= count) {
        continue;
      }
      final record = expected[seen.length];
      expect(card.title, record.name, reason: 'card ${seen.length + 1}');
      expect(card.image, record.thumbnail, reason: '${record.name} art');
      final image = find.descendant(
        of: find.byElementPredicate((e) => identical(e, element)),
        matching: find.byType(Image),
      );
      expect(
        tester.widget<Image>(image).image,
        bundledArtFor(record.thumbnail),
        reason: '${record.name} draws its bundled asset',
      );
      seen.add(card.title!);
    }
    if (seen.length < count) {
      await tester.drag(charactersScrollable(), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(seen, [for (final c in expected) c.name]);
}
