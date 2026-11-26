import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap {'Add to favourites'} on page {1}
///
/// Taps the label on that page only (`I open comic {id} on two pages`).
Future<void> iTapOnPage(WidgetTester tester, String label, int page) async {
  final target = find
      .descendant(
        of: find.byKey(comicPageKey(page)),
        matching: find.text(label),
      )
      .hitTestable();
  expect(target, findsOneWidget, reason: 'one tappable "$label" on page $page');
  await tester.tap(target);
  await mcSettle(tester);
}
