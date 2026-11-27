import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the {'deals'} section shows its error with Retry
///
/// The section's own error card, with a Retry button, and none of its
/// content or skeleton.
Future<void> theSectionShowsItsErrorWithRetry(
  WidgetTester tester,
  String section,
) async {
  await letSectionsLand(tester);
  final error = find.byKey(sectionPartKey(section, 'error'));
  await scrollStoreUntilVisible(tester, error);
  expect(error, findsOneWidget, reason: 'the $section error card');
  await tester.ensureVisible(error);
  await tester.pump();
  expect(
    find.descendant(of: error, matching: find.text(retryLabel(tester))),
    findsOneWidget,
    reason: 'the $section error card has Retry',
  );
  for (final part in ['content', 'skeleton']) {
    expect(find.byKey(sectionPartKey(section, part)), findsNothing);
  }
}
