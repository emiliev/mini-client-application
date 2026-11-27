import 'package:mc_fixtures_commerce/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const CommerceMockDomain();
MockDomain _empty() => const EmptyCommerceDomain();
MockDomain _serverError() => const FailingCommerceDomain();
MockDomain _banners() => const SectionFailingCommerceDomain('banners');
MockDomain _deals() => const SectionFailingCommerceDomain('deals');
MockDomain _categories() => const SectionFailingCommerceDomain('categories');
MockDomain _categoryProducts() =>
    const SectionFailingCommerceDomain('category_products');
MockDomain _featured() => const SectionFailingCommerceDomain('featured');
MockDomain _cart() => const SectionFailingCommerceDomain('cart');

/// The named fixture sets of this domain (plan 05 §3.4), switched on per test
/// like `libraryFixtureSets`. Facts the tests rely on are in CONTRACT.md,
/// "Fixture sets".
const Map<String, MockDomain Function()> commerceFixtureSets = {
  'commerce.default': _default,
  'commerce.empty': _empty,
  'commerce.server_error': _serverError,
  'commerce.banners_error': _banners,
  'commerce.deals_error': _deals,
  'commerce.categories_error': _categories,
  'commerce.category_products_error': _categoryProducts,
  'commerce.featured_error': _featured,
  'commerce.cart_error': _cart,
};
