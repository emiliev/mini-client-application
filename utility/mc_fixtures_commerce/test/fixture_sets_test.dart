import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'support.dart';

MockBackend _set(String name) =>
    MockBackend(domains: [commerceFixtureSets[name]!()]);

/// Every route with valid inputs (the cart ones with a valid bearer).
const List<(String, String, Object?)> _calls = [
  ('GET', '/v1/store/banners', null),
  ('GET', '/v1/store/deals', null),
  ('GET', '/v1/store/categories', null),
  ('GET', '/v1/store/categories/heroes/products', null),
  ('GET', '/v1/store/featured', null),
  ('GET', '/v1/me/cart', null),
  ('PUT', '/v1/me/cart/items/500060', {'quantity': 1}),
  ('POST', '/v1/me/cart/promo', {'code': 'SAVE10'}),
  ('DELETE', '/v1/me/cart/promo', null),
];

/// Runs [_calls] in order on [backend]; returns `status body` per call.
Future<List<String>> _session(MockBackend backend) async {
  final dio = plainDio(backend);
  return [
    for (final (method, path, body) in _calls)
      await (() async {
        final r = await call<String>(
          dio,
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        return '${r.statusCode} ${r.data}';
      })(),
  ];
}

void main() {
  test('T-0051-AC2: the fixture sets are default, empty, server_error and one per section', () {
    expect(commerceFixtureSets.keys, [
      'commerce.default',
      'commerce.empty',
      'commerce.server_error',
      'commerce.banners_error',
      'commerce.deals_error',
      'commerce.categories_error',
      'commerce.category_products_error',
      'commerce.featured_error',
      'commerce.cart_error',
    ]);
    expect(
      commerceFixtureSets['commerce.default']!(),
      isA<CommerceMockDomain>(),
    );
    expect(
      commerceFixtureSets['commerce.empty']!(),
      isA<EmptyCommerceDomain>(),
    );
    expect(
      commerceFixtureSets['commerce.server_error']!(),
      isA<FailingCommerceDomain>(),
    );
    expect(
      commerceSections.keys.map((k) => 'commerce.${k}_error'),
      commerceFixtureSets.keys.skip(3),
    );
    expect(commerceRouteManifest, CommerceMockDomain.routeManifest);
    for (final set in commerceFixtureSets.values) {
      expect(
        set().scenarios,
        set() is CommerceMockDomain ? isNotEmpty : isEmpty,
      );
    }
  });

  test(
    'T-0051-AC2: the default set serves every section and the cart',
    () async {
      final session = await _session(_set('commerce.default'));
      expect(session.take(6).every((s) => s.startsWith('200 ')), isTrue);
      expect(session[6], startsWith('200 '));
      expect(session[7], startsWith('200 '));
      expect(session[8], startsWith('200 '));
    },
  );

  test('T-0051-AC2: commerce.empty has nothing to show and nothing to buy, but auth and validation work', () async {
    final backend = _set('commerce.empty');
    final dio = jsonDio(backend);
    expect((await getJson(dio, '/v1/store/banners')).data, {
      'banners': <Object?>[],
    });
    expect((await getJson(dio, '/v1/store/deals')).data, {
      'deals': <Object?>[],
    });
    expect((await getJson(dio, '/v1/store/categories')).data, {
      'categories': <Object?>[],
    });
    expect((await getJson(dio, '/v1/store/featured')).data, {
      'products': <Object?>[],
    });
    final category = await getJson(dio, '/v1/store/categories/heroes/products');
    expect(category.statusCode, 404);
    expect((category.data!['error']! as Json)['code'], 'unknown_category');
    expect((await getJson(dio, '/v1/me/cart')).statusCode, 401);
    final cart = await getJson(dio, '/v1/me/cart', user: reader);
    expect(cart.data!['items'], isEmpty);
    final put = await putQuantity(dio, 500060, 1);
    expect(put.statusCode, 404);
    expect((put.data!['error']! as Json)['code'], 'unknown_product');
    final promo = await applyCode(dio, 'SAVE10');
    expect(promo.statusCode, 409);
    expect((promo.data!['error']! as Json)['reason'], 'empty_cart');
  });

  test('T-0051-AC2: commerce.server_error answers 500 on every route, with the scenario\'s body', () async {
    final set = await _session(_set('commerce.server_error'));
    final scenario = await _session(
      MockBackend(domains: [const CommerceMockDomain()])
        ..useScenario('commerce.server_error'),
    );
    expect(set.every((s) => s.startsWith('500 ')), isTrue);
    expect(set, scenario);
    expect(set.first, contains('"code":"injected_failure"'));
    expect(set.first, contains('Injected HTTP 500 for GET /v1/store/banners'));
  });

  test(
    'T-0051-AC2: commerce.empty set and scenario answer the same bodies',
    () async {
      final set = await _session(_set('commerce.empty'));
      final scenario = await _session(
        MockBackend(domains: [const CommerceMockDomain()])
          ..useScenario('commerce.empty'),
      );
      expect(set, scenario);
      expect(set.last, startsWith('200 '));
    },
  );

  for (final section in commerceSections.entries) {
    test(
      'T-0051-AC2: commerce.${section.key}_error and store.${section.key}_error answer the same bodies, failing only that section',
      () async {
        final set = await _session(_set('commerce.${section.key}_error'));
        final scenario = await _session(
          MockBackend(domains: [const CommerceMockDomain()])
            ..useScenario('store.${section.key}_error'),
        );
        expect(set, scenario);
        final healthy = await _session(_set('commerce.default'));
        var failed = 0;
        for (var i = 0; i < _calls.length; i++) {
          final (method, path, _) = _calls[i];
          final key =
              '$method ${path.replaceAll(RegExp(r'/heroes/'), '/:id/').replaceAll(RegExp(r'/\d+$'), '/:productId')}';
          final inSection = section.value.contains(key);
          if (inSection) {
            failed++;
            expect(set[i], startsWith('500 '), reason: key);
            expect(set[i], contains('Injected HTTP 500 for $method $path'));
          } else {
            expect(set[i], healthy[i], reason: '$key is untouched');
          }
        }
        expect(failed, section.value.length);
      },
    );
  }

  test(
    'T-0051-AC2: an unknown section is an ArgumentError listing the valid ones',
    () {
      expect(
        () => SectionFailingCommerceDomain('deal'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('category_products'), contains('banners')),
          ),
        ),
      );
    },
  );

  test(
    'T-0051-AC2: each section failure is its own scenario, none is shared',
    () {
      final names = MockBackend(
        domains: [const CommerceMockDomain()],
      ).scenarioNames.toList()..sort();
      expect(names, CommerceMockDomain.scenarioNames);
      expect(names, containsAll(['store.deals_error', 'store.banners_error']));
      final covered = commerceSections.values.expand((r) => r).toList();
      expect(
        covered..sort(),
        [...commerceRouteManifest]..sort(),
        reason: 'sections partition the routes',
      );
    },
  );
}
