import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the {'deals'} section is loading
///
/// The section shows its own skeleton, and neither content nor error.
Future<void> theSectionIsLoading(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  final skeleton = find.byKey(sectionPartKey(section, 'skeleton'));
  await scrollStoreUntilVisible(tester, skeleton);
  expect(skeleton, findsOneWidget, reason: 'the $section skeleton');
  for (final part in ['content', 'error', 'empty']) {
    expect(find.byKey(sectionPartKey(section, part)), findsNothing);
  }
}
