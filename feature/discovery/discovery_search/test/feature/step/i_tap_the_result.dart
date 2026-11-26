import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/discovery_search_env.dart';

/// Usage: I tap the result {'Spindle Chronicles #1'}
///
/// Scrolls the results until the row titled [title] is on screen, then taps
/// it once.
Future<void> iTapTheResult(WidgetTester tester, String title) async {
  final row = find.descendant(
    of: find.byKey(searchResultsKey),
    matching: find.text(title),
  );
  await tester.scrollUntilVisible(row, 200, scrollable: resultsScrollable());
  await mcSettle(tester);
  expect(row.hitTestable(), findsOneWidget, reason: 'one "$title" row');
  await tester.tap(row.hitTestable());
  await mcSettle(tester);
}
