import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the banners section shows every banner of the store
///
/// Each of the fixtures' banners, in their order, with its title and
/// subtitle (the carousel is scrolled forward only, so the order is proven).
Future<void> theBannersSectionShowsEveryBannerOfTheStore(
  WidgetTester tester,
) async {
  await letSectionsLand(tester);
  final banners = storeCatalogue.banners;
  expect(banners, hasLength(4), reason: 'the contract has 4 banners');
  for (final banner in banners) {
    final card = find.byKey(bannerKey(banner['id']! as String));
    await scrollCarouselTo(tester, 'banners', card);
    for (final text in [
      banner['title']! as String,
      banner['subtitle']! as String,
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
        reason: 'banner ${banner['id']} shows "$text"',
      );
    }
  }
}
