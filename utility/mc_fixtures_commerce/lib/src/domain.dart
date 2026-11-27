import 'package:mc_fixtures_commerce/src/handlers/cart_handlers.dart' as cart;
import 'package:mc_fixtures_commerce/src/handlers/store_handlers.dart' as store;
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the commerce domain, as `"METHOD /pattern"`. Documented in
/// `CONTRACT.md`; the same routes are listed in `fixtures/routes.json`, and a
/// test keeps the three in step.
const List<String> commerceRouteManifest = [
  'GET /v1/store/banners',
  'GET /v1/store/deals',
  'GET /v1/store/categories',
  'GET /v1/store/categories/:id/products',
  'GET /v1/store/featured',
  'GET /v1/me/cart',
  'PUT /v1/me/cart/items/:productId',
  'POST /v1/me/cart/promo',
  'DELETE /v1/me/cart/promo',
];

/// The independently failing parts of the domain (P1-21 AC6): each name is
/// the part of the `store.<name>_error` scenario and the
/// `commerce.<name>_error` set, and lists the routes it fails.
const Map<String, List<String>> commerceSections = {
  'banners': ['GET /v1/store/banners'],
  'deals': ['GET /v1/store/deals'],
  'categories': ['GET /v1/store/categories'],
  'category_products': ['GET /v1/store/categories/:id/products'],
  'featured': ['GET /v1/store/featured'],
  'cart': [
    'GET /v1/me/cart',
    'PUT /v1/me/cart/items/:productId',
    'POST /v1/me/cart/promo',
    'DELETE /v1/me/cart/promo',
  ],
};

Map<String, MockHandler> _handlers({required bool empty}) => {
  'GET /v1/store/banners': store.banners(empty: empty),
  'GET /v1/store/deals': store.deals(empty: empty),
  'GET /v1/store/categories': store.categories(empty: empty),
  'GET /v1/store/categories/:id/products': store.categoryProducts(
    empty: empty,
  ),
  'GET /v1/store/featured': store.featured(empty: empty),
  'GET /v1/me/cart': cart.getCart(empty: empty),
  'PUT /v1/me/cart/items/:productId': cart.putItem(empty: empty),
  'POST /v1/me/cart/promo': cart.applyPromo(empty: empty),
  'DELETE /v1/me/cart/promo': cart.removePromo(empty: empty),
};

void _register(MockRouter router, Map<String, MockHandler> byRoute) {
  for (final MapEntry(:key, :value) in byRoute.entries) {
    final [method, pattern] = key.split(' ');
    router.add(method, pattern, value);
  }
}

FailureRule _fail(String route) => FailureRule(
  route.split(' ').first,
  route.split(' ').last,
  const FailureKind.http(500),
);

/// The commerce domain: the store sections and the signed-in user's cart. The
/// cart lives in the backend's store (kept until `reset()`); it needs a
/// bearer from `mc_fixtures_identity`.
final class CommerceMockDomain implements MockDomain {
  const CommerceMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = commerceRouteManifest;

  /// The scenario names, in the order of `fixtures/routes.json`.
  static const List<String> scenarioNames = [
    'commerce.empty',
    'commerce.server_error',
    'store.banners_error',
    'store.cart_error',
    'store.categories_error',
    'store.category_products_error',
    'store.deals_error',
    'store.featured_error',
  ];

  @override
  String get name => 'commerce';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, _handlers(empty: false));

  @override
  Map<String, MockScenario> get scenarios => {
    'commerce.empty': MockScenario(
      'commerce.empty',
      overrides: _handlers(empty: true),
    ),
    'commerce.server_error': MockScenario(
      'commerce.server_error',
      rules: [for (final route in commerceRouteManifest) _fail(route)],
    ),
    for (final MapEntry(:key, :value) in commerceSections.entries)
      'store.${key}_error': MockScenario(
        'store.${key}_error',
        rules: [for (final route in value) _fail(route)],
      ),
  };
}

/// The same routes with an empty store: no banners, deals, categories or
/// products, and a cart that cannot hold anything (the `commerce.empty` set).
/// It has no scenarios.
final class EmptyCommerceDomain implements MockDomain {
  const EmptyCommerceDomain();

  @override
  String get name => 'commerce';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, _handlers(empty: true));

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The same routes, each answering `500` (the `commerce.server_error` set).
/// It has no scenarios.
final class FailingCommerceDomain implements MockDomain {
  const FailingCommerceDomain();

  @override
  String get name => 'commerce';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, {
        for (final route in commerceRouteManifest) route: store.serverError,
      });

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The default domain with one section failing (`commerce.<section>_error`):
/// the routes of [section] answer `500`, every other route works. It has no
/// scenarios.
final class SectionFailingCommerceDomain implements MockDomain {
  SectionFailingCommerceDomain(this.section) {
    if (!commerceSections.containsKey(section)) {
      throw ArgumentError.value(
        section,
        'section',
        'Unknown section. Valid: ${commerceSections.keys.toList()}',
      );
    }
  }

  /// A key of [commerceSections].
  final String section;

  @override
  String get name => 'commerce';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, {
        ..._handlers(empty: false),
        for (final route in commerceSections[section]!)
          route: store.serverError,
      });

  @override
  Map<String, MockScenario> get scenarios => const {};
}
