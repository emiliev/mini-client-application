import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the categories section shows every category of the store
///
/// Each of the fixtures' six categories, with its name and comic count.
Future<void> theCategoriesSectionShowsEveryCategoryOfTheStore(
  WidgetTester tester,
) async {
  await letSectionsLand(tester);
  final categories = storeCatalogue.categories;
  expect(categories, hasLength(6), reason: 'the contract has 6 categories');
  for (final category in categories) {
    final tile = find.byKey(categoryKey(category.id));
    await scrollStoreUntilVisible(tester, tile);
    final count = storeCatalogue.productsOf(category.id).length;
    for (final text in [category.name, '$count comics']) {
      expect(
        find.descendant(of: tile, matching: find.text(text)),
        findsOneWidget,
        reason: 'category ${category.id} shows "$text"',
      );
    }
  }
}
