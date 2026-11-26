import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the creator {'Esme Garrow'}
///
/// Scrolls the credit into view, then taps it.
Future<void> iTapTheCreator(WidgetTester tester, String name) async {
  final credit = find.descendant(
    of: find.byKey(comicCreditsKey),
    matching: find.text(name),
  );
  await scrollComicUntilVisible(tester, credit);
  expect(
    credit.hitTestable(),
    findsOneWidget,
    reason: 'one tappable credit "$name"',
  );
  await tester.tap(credit.hitTestable());
  await mcSettle(tester);
}
