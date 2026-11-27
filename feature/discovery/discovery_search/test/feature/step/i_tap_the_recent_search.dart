import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: I tap the recent search {'amber'}
///
/// Taps the recent search [query] and draws one frame with no fake time
/// passing (zero-delay timers still run): a search that waited for a
/// debounce would not have gone out.
Future<void> iTapTheRecentSearch(WidgetTester tester, String query) async {
  final row = find
      .descendant(of: find.byKey(searchHistoryKey), matching: find.text(query))
      .hitTestable();
  expect(row, findsOneWidget, reason: 'one recent search "$query"');
  await tester.tap(row);
  await tester.pump(Duration.zero);
}
