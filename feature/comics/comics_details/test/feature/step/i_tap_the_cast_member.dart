import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cast member {'Amber Vanguard'}
///
/// Scrolls the cast row into view, then taps that character's card.
Future<void> iTapTheCastMember(WidgetTester tester, String name) async {
  final row = find.byKey(comicCastKey);
  await scrollComicUntilVisible(tester, row);
  final card = find
      .descendant(of: row, matching: find.text(name))
      .hitTestable();
  expect(card, findsOneWidget, reason: 'one tappable cast card "$name"');
  await tester.tap(card);
  await mcSettle(tester);
}
