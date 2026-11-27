import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the sections are {'Highlights, Deals, Categories, Featured, Your cart'}
///
/// The section headers from the top of the store to its end are exactly
/// these, in this order.
Future<void> theSectionsAre(WidgetTester tester, String titles) async {
  await letSectionsLand(tester);
  expect(
    await sectionTitlesInOrder(tester),
    [for (final t in titles.split(',')) t.trim()],
    reason: 'the sections, top to bottom',
  );
}
