import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// A request made before the snapshotted one, on the same backend and as the
/// same user (so the cart has something in it).
typedef Setup = (String method, String path, Object? body);

/// One request of the provider snapshots, run on a fresh default backend.
final class SnapshotCase {
  const SnapshotCase(
    this.method,
    this.path, {
    this.body,
    this.user = 'u-100',
    this.setup = const [],
    this.scenario,
  });

  final String method;
  final String path;
  final Object? body;

  /// The user whose access token is sent; `none` sends no bearer and
  /// `expired` sends u-100's expired one.
  final String user;
  final List<Setup> setup;
  final String? scenario;
}

final Catalogue _catalogue = catalogueFor(42, empty: false);

/// Heroes at full price with a healthy stock, dearest last.
final List<Product> _heroes = _catalogue
    .productsOf('heroes')
    .where((p) => p.deal == null && p.stock >= 6)
    .take(3)
    .toList();
final Product _deal = _catalogue.deals.first;
final Product _soldOut = _catalogue.products.firstWhere((p) => p.stock == 0);
final Product _limited = _catalogue.products.firstWhere((p) => p.stock == 6);

Setup _put(int id, int quantity) => (
  'PUT',
  '/v1/me/cart/items/$id',
  {'quantity': quantity},
);

Setup _promo(String code) => ('POST', '/v1/me/cart/promo', {'code': code});

final List<Setup> _heroLines = [
  for (final p in _heroes) _put(p.id, 2),
];

/// The provider snapshot cases: name -> request.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_commerce/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
final Map<String, SnapshotCase> snapshotCases = {
  'banners': const SnapshotCase('GET', '/v1/store/banners'),
  'deals': const SnapshotCase('GET', '/v1/store/deals'),
  'categories': const SnapshotCase('GET', '/v1/store/categories'),
  'category_products': const SnapshotCase(
    'GET',
    '/v1/store/categories/heroes/products?limit=3',
  ),
  'category_products_page': const SnapshotCase(
    'GET',
    '/v1/store/categories/cosmic/products?offset=55&limit=10',
  ),
  'category_unknown': const SnapshotCase(
    'GET',
    '/v1/store/categories/nope/products',
  ),
  'category_invalid_limit': const SnapshotCase(
    'GET',
    '/v1/store/categories/heroes/products?limit=101',
  ),
  'featured': const SnapshotCase('GET', '/v1/store/featured'),
  'deals_error': const SnapshotCase(
    'GET',
    '/v1/store/deals',
    scenario: 'store.deals_error',
  ),
  'cart_empty': const SnapshotCase('GET', '/v1/me/cart'),
  'cart_one_line': SnapshotCase(
    'GET',
    '/v1/me/cart',
    setup: [_put(_heroes[0].id, 2)],
  ),
  'cart_other_user': SnapshotCase(
    'GET',
    '/v1/me/cart',
    user: 'u-101',
    setup: [_put(_heroes[0].id, 2)],
  ),
  'put_item': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_heroes[1].id}',
    body: const {'quantity': 3},
    setup: [_put(_heroes[0].id, 1)],
  ),
  'put_item_remove': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_heroes[0].id}',
    body: const {'quantity': 0},
    setup: [_put(_heroes[0].id, 1), _put(_heroes[1].id, 1)],
  ),
  'cart_deal_line': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_deal.id}',
    body: const {'quantity': 2},
  ),
  'promo_percent': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'save10'},
    setup: _heroLines,
  ),
  'promo_buy_2_get_1': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'HEROES3'},
    setup: _heroLines,
  ),
  'promo_fixed': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'TAKE5'},
    setup: _heroLines,
  ),
  'cart_stacked': SnapshotCase(
    'GET',
    '/v1/me/cart',
    setup: [
      ..._heroLines,
      _promo('TAKE5'),
      _promo('SAVE25'),
      _promo('HEROES3'),
    ],
  ),
  'promo_removed_one': SnapshotCase(
    'DELETE',
    '/v1/me/cart/promo?code=SAVE25',
    setup: [..._heroLines, _promo('SAVE25'), _promo('HEROES3')],
  ),
  'promo_removed_all': SnapshotCase(
    'DELETE',
    '/v1/me/cart/promo',
    setup: [..._heroLines, _promo('SAVE25'), _promo('HEROES3')],
  ),
  'unauthenticated': const SnapshotCase('GET', '/v1/me/cart', user: 'none'),
  'expired_token': const SnapshotCase('GET', '/v1/me/cart', user: 'expired'),
  'unknown_product': const SnapshotCase(
    'PUT',
    '/v1/me/cart/items/12345',
    body: {'quantity': 1},
  ),
  'invalid_quantity': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_heroes[0].id}',
    body: const {'quantity': 100},
  ),
  'invalid_body': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_heroes[0].id}',
    body: const [1],
  ),
  'out_of_stock_sold_out': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_soldOut.id}',
    body: const {'quantity': 1},
  ),
  'out_of_stock_over': SnapshotCase(
    'PUT',
    '/v1/me/cart/items/${_limited.id}',
    body: const {'quantity': 7},
  ),
  'unknown_promo': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'FREEBIES'},
    setup: [_put(_heroes[0].id, 1)],
  ),
  'promo_empty_cart': const SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: {'code': 'SAVE10'},
  ),
  'promo_already_applied': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'SAVE10'},
    setup: [_put(_heroes[0].id, 1), _promo('SAVE10')],
  ),
  'promo_kind_already_applied': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'SAVE25'},
    setup: [_put(_heroes[0].id, 1), _promo('SAVE10')],
  ),
  'promo_no_matching_items': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'COSMIC3'},
    setup: [_put(_heroes[0].id, 3)],
  ),
  'promo_minimum_not_met': SnapshotCase(
    'POST',
    '/v1/me/cart/promo',
    body: const {'code': 'TAKE15'},
    setup: [_put(_heroes[0].id, 1)],
  ),
  'promo_not_applied': SnapshotCase(
    'DELETE',
    '/v1/me/cart/promo?code=TAKE5',
    setup: [_put(_heroes[0].id, 1)],
  ),
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const CommerceMockDomain()]);

/// Runs one case and returns `{"request", "setup", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(SnapshotCase c) async {
  final headers = switch (c.user) {
    'none' => <String, String>{},
    'expired' => {'Authorization': 'Bearer ${expiredAccessToken('u-100')}'},
    final id => {'Authorization': 'Bearer ${mintAccessToken(id, 1)}'},
  };
  final backend = snapshotBackend();
  final dio = backend.createDio();
  Future<Response<String>> send(String method, String path, Object? body) =>
      dio.request<String>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
  for (final (method, path, body) in c.setup) {
    final r = await send(method, path, body);
    if (r.statusCode != 200) {
      throw StateError('setup $method $path failed: ${r.statusCode} ${r.data}');
    }
  }
  if (c.scenario != null) {
    backend.useScenario(c.scenario);
  }
  final response = await send(c.method, c.path, c.body);
  final text = response.data;
  return {
    'request': '${c.method} ${c.path} as ${c.user}',
    if (c.scenario != null) 'scenario': c.scenario,
    if (c.setup.isNotEmpty)
      'setup': [
        for (final (m, p, b) in c.setup)
          '$m $p${b == null ? '' : ' ${jsonEncode(b)}'}',
      ],
    if (c.body != null) 'requestBody': c.body,
    'status': response.statusCode,
    'body': text == null || text.isEmpty ? null : jsonDecode(text),
  };
}
