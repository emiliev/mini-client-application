import 'package:mc_monitoring/mc_monitoring.dart';

/// The screen names of the flow's two pages: their `McFlowPage` names, which
/// `AnalyticsFlowObserver` tracks. The first equals the app route's name
/// (`/store` is `store_home`), so it is not tracked twice.
const String storeHomeScreen = 'store_home';
const String storeCategoryScreen = 'store_category';

/// A section reached `ready` for the first time in this visit.
const String storeSectionViewedEvent = 'store_section_viewed';

/// An item of the store was tapped.
const String storeItemTappedEvent = 'store_item_tapped';

/// Where on the store something was seen or tapped: the analytics `section`
/// parameter.
enum StoreSection {
  banners('banners'),
  deals('deals'),
  categories('categories'),
  featured('featured'),
  cart('cart'),

  /// The products of the category page (not a section of the home, so it
  /// has no `store_section_viewed`).
  categoryProducts('category_products');

  const StoreSection(this.wireName);

  final String wireName;
}

/// What a tapped item leads to: the analytics `kind` parameter.
enum StoreItemKind {
  comic('comic'),
  category('category'),
  search('search'),
  cart('cart');

  const StoreItemKind(this.wireName);

  final String wireName;
}

/// The store's analytics vocabulary over the blocs' pure-Dart port
/// (`AnalyticsTracker`, R15): event names and params are spelled once, here.
extension StoreTracking on AnalyticsTracker {
  /// `store_section_viewed` with `section`.
  void sectionViewed(StoreSection section) =>
      trackEvent(storeSectionViewedEvent, {'section': section.wireName});

  /// `store_item_tapped` with `section`, `kind` and `id` (the target's id:
  /// a comic id, a category id, a search query, or `summary` for the cart).
  void itemTapped(StoreSection section, StoreItemKind kind, String id) =>
      trackEvent(storeItemTappedEvent, {
        'section': section.wireName,
        'kind': kind.wireName,
        'id': id,
      });
}
