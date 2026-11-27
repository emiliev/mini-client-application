import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the {'deals'} section is ready
///
/// The section shows its content, and neither its skeleton nor its error.
Future<void> theSectionIsReady(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  final content = find.byKey(sectionPartKey(section, 'content'));
  await scrollStoreUntilVisible(tester, content);
  expect(content, findsOneWidget, reason: 'the $section content');
  for (final part in ['error', 'skeleton', 'empty']) {
    expect(
      find.byKey(sectionPartKey(section, part)),
      findsNothing,
      reason: 'the $section section is not $part',
    );
  }
}
