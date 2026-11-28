import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';

import '../util/characters_list_env.dart';

/// Usage: the characters list shows the first {30} characters of team {'Harbor Watch'}
///
/// The grid is not empty, and walking it with real drags shows exactly the
/// first [count] characters of [team] in name order: every card is one of
/// that team's, and none of another team's comes between them.
Future<void> theCharactersListShowsTheFirstCharactersOfTeam(
  WidgetTester tester,
  int count,
  String team,
) async {
  final expected = [
    for (final c in defaultCast)
      if (c.team == team) c.name,
  ].take(count).toList();
  expect(expected, hasLength(count), reason: 'the cast has $count of $team');
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
      final title = (element.widget as McMediaCard).title!;
      if (!seen.contains(title) && seen.length < count) {
        seen.add(title);
      }
    }
    if (seen.length < count) {
      await tester.drag(charactersScrollable(), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  expect(seen, expected);
}
