import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'support.dart';

Json _error(Response<Json> r) => r.data!['error']! as Json;

Future<Response<Json>> _cart(Dio dio, {String user = reader}) =>
    getJson(dio, '/v1/me/cart', user: user);

/// A product with a stock of at least [stock] (and none of a deal).
ProductView _withStock(Map<int, ProductView> products, int stock) =>
    products.values.firstWhere((p) => p.stock >= stock);

void main() {
  late MockBackend backend;
  late Dio dio;
  late Map<int, ProductView> products;
  setUp(() async {
    backend = commerceBackend();
    dio = jsonDio(backend);
    products = await loadProducts(dio);
  });

  group('T-0051-AC4 auth', () {
    const routes = <(String, String, Object?)>[
      ('GET', '/v1/me/cart', null),
      ('PUT', '/v1/me/cart/items/500060', {'quantity': 1}),
      ('POST', '/v1/me/cart/promo', {'code': 'SAVE10'}),
      ('DELETE', '/v1/me/cart/promo', null),
    ];

    test('T-0051-AC4: every cart route answers 401 without a bearer', () async {
      for (final (method, path, body) in routes) {
        final r = await call<Json>(dio, method, path, body: body);
        expect(r.statusCode, 401, reason: '$method $path');
        expect(_error(r)['code'], 'unauthenticated');
      }
    });

    test('T-0051-AC4: a malformed, expired or refresh token, a wrong scheme or an unknown user is a 401', () async {
      final bad = <String, String>{
        'not a bearer': 'Basic abc',
        'garbage': 'Bearer nonsense',
        'expired': 'Bearer ${expiredAccessToken(reader)}',
        'refresh as bearer': 'Bearer ${mintRefreshToken(reader, 1)}',
        'unknown user': 'Bearer ${mintAccessToken('u-999', 1)}',
        'empty': '',
      };
      for (final MapEntry(:key, :value) in bad.entries) {
        for (final (method, path, body) in routes) {
          final r = await call<Json>(
            dio,
            method,
            path,
            body: body,
            headers: {'Authorization': value},
          );
          expect(r.statusCode, 401, reason: '$key: $method $path');
        }
      }
    });

    test(
      'T-0051-AC4: auth is checked before the product and the body',
      () async {
        final r = await call<Json>(
          dio,
          'PUT',
          '/v1/me/cart/items/not-a-product',
          body: [1, 2],
        );
        expect(r.statusCode, 401);
      },
    );

    test('T-0051-AC4: the store sections need no bearer', () async {
      for (final path in const [
        '/v1/store/banners',
        '/v1/store/deals',
        '/v1/store/categories',
        '/v1/store/categories/heroes/products',
        '/v1/store/featured',
      ]) {
        expect((await getJson(dio, path)).statusCode, 200, reason: path);
      }
    });
  });

  group('T-0051-AC4 typed codes', () {
    test(
      'T-0051-AC4: unknown_product (404) for an id that is not sold',
      () async {
        final notSold = ComicUniverse(
          42,
        ).byTitle.firstWhere((c) => c.issueNumber > issuesSold);
        for (final raw in ['999', 'abc', '${notSold.id}', '-1', '1.5']) {
          final r = await call<Json>(
            dio,
            'PUT',
            '/v1/me/cart/items/$raw',
            body: {'quantity': 1},
            headers: bearer(reader),
          );
          expect(r.statusCode, 404, reason: raw);
          expect(_error(r), containsPair('code', 'unknown_product'));
          expect(_error(r)['productId'], raw);
        }
        // The product check comes before the quantity check.
        final first = await call<Json>(
          dio,
          'PUT',
          '/v1/me/cart/items/999',
          body: {'quantity': 1000},
          headers: bearer(reader),
        );
        expect(_error(first)['code'], 'unknown_product');
      },
    );

    test('T-0051-AC4: invalid_quantity (400) outside 0 to 99 or not a whole number', () async {
      final p = _withStock(products, 99);
      for (final q in <Object?>[
        -1,
        100,
        1000,
        1.5,
        2.0,
        '2',
        null,
        true,
        <int>[],
      ]) {
        final r = await putQuantity(dio, p.id, q);
        expect(r.statusCode, 400, reason: '$q');
        expect(_error(r)['code'], 'invalid_quantity', reason: '$q');
        expect(_error(r)['min'], 0);
        expect(_error(r)['max'], 99);
      }
      // The boundaries are valid.
      expect((await putQuantity(dio, p.id, 99)).statusCode, 200);
      expect((await putQuantity(dio, p.id, 0)).statusCode, 200);
      expect((await putQuantity(dio, p.id, 1)).statusCode, 200);
      // A missing quantity is the same error.
      final missing = await call<Json>(
        dio,
        'PUT',
        '/v1/me/cart/items/${p.id}',
        body: <String, Object?>{},
        headers: bearer(reader),
      );
      expect(_error(missing)['code'], 'invalid_quantity');
      // The range is checked before the stock.
      final empty = products.values.firstWhere((p) => p.stock == 0);
      expect(
        _error(await putQuantity(dio, empty.id, 100))['code'],
        'invalid_quantity',
      );
    });

    test(
      'T-0051-AC4: invalid_body (400) for a body that is not an object',
      () async {
        final p = _withStock(products, 1);
        final r = await call<Json>(
          dio,
          'PUT',
          '/v1/me/cart/items/${p.id}',
          body: [1],
          headers: bearer(reader),
        );
        expect(r.statusCode, 400);
        expect(_error(r), containsPair('code', 'invalid_body'));
        for (final body in <Object?>[
          [1],
          <String, Object?>{},
          {'code': 5},
        ]) {
          final promo = await call<Json>(
            dio,
            'POST',
            '/v1/me/cart/promo',
            body: body,
            headers: bearer(reader),
          );
          expect(promo.statusCode, 400, reason: '$body');
          expect(_error(promo)['code'], 'invalid_body', reason: '$body');
        }
      },
    );

    test(
      'T-0051-AC4: out_of_stock (409) above the stock, with the stock named',
      () async {
        final empty = products.values.firstWhere((p) => p.stock == 0);
        final r = await putQuantity(dio, empty.id, 1);
        expect(r.statusCode, 409);
        expect(_error(r), containsPair('code', 'out_of_stock'));
        expect(_error(r)['available'], 0);
        expect(_error(r)['requested'], 1);
        expect(_error(r)['productId'], empty.id);
        final limited = products.values.firstWhere((p) => p.stock == 3);
        expect((await putQuantity(dio, limited.id, 3)).statusCode, 200);
        final over = await putQuantity(dio, limited.id, 4);
        expect(over.statusCode, 409);
        expect(_error(over)['available'], 3);
        // A rejected write changes nothing.
        final cart = (await _cart(dio)).data!;
        expect((cart['items']! as List).cast<Json>().single['quantity'], 3);
        // Taking an out-of-stock product out is still allowed.
        expect((await putQuantity(dio, empty.id, 0)).statusCode, 200);
      },
    );

    test('T-0051-AC4: unknown_promo (404), and codes are trimmed and case-insensitive', () async {
      final p = _withStock(products, 1);
      await putQuantity(dio, p.id, 1);
      for (final code in ['NOPE', '', 'SAVE', 'SAVE10X']) {
        final r = await applyCode(dio, code);
        expect(r.statusCode, 404, reason: code);
        expect(_error(r)['code'], 'unknown_promo');
      }
      final ok = await applyCode(dio, '  save10 ');
      expect(ok.statusCode, 200);
      expect(
        (ok.data!['promotions']! as List).cast<Json>().single['code'],
        'SAVE10',
      );
      final unknownRemoval = await call<Json>(
        dio,
        'DELETE',
        '/v1/me/cart/promo?code=NOPE',
        headers: bearer(reader),
      );
      expect(_error(unknownRemoval)['code'], 'unknown_promo');
    });

    test('T-0051-AC4: promo_not_applicable (409) names its reason and changes nothing', () async {
      Future<String> reasonOf(String code) async {
        final r = await applyCode(dio, code);
        expect(r.statusCode, 409, reason: code);
        expect(_error(r)['code'], 'promo_not_applicable', reason: code);
        expect(_error(r)['code'], isNot('unknown_promo'));
        return _error(r)['reason']! as String;
      }

      expect(await reasonOf('SAVE10'), 'empty_cart');
      final cosmic = inCategory(
        products,
        'cosmic',
        minStock: 1,
      ).firstWhere((p) => p.unitCents < 1500);
      await putQuantity(dio, cosmic.id, 1);
      expect(await reasonOf('HEROES3'), 'no_matching_items');
      expect(await reasonOf('TAKE5'), 'minimum_not_met');
      expect((await applyCode(dio, 'SAVE10')).statusCode, 200);
      expect(await reasonOf('SAVE10'), 'already_applied');
      expect(await reasonOf('SAVE25'), 'kind_already_applied');
      final removed = await call<Json>(
        dio,
        'DELETE',
        '/v1/me/cart/promo?code=TAKE5',
        headers: bearer(reader),
      );
      expect(removed.statusCode, 409);
      expect(_error(removed)['reason'], 'not_applied');
      // Every refusal left the cart as it was: one code, one line.
      final cart = (await _cart(dio)).data!;
      expect((cart['promotions']! as List).cast<Json>().map((p) => p['code']), [
        'SAVE10',
      ]);
      expect(cart['items'], hasLength(1));
    });
  });

  group('T-0051-AC4 per-user carts that persist until reset()', () {
    test('T-0051-AC4: a cart persists across requests', () async {
      final p = _withStock(products, 2);
      await putQuantity(dio, p.id, 2);
      await applyCode(dio, 'SAVE10');
      for (var i = 0; i < 3; i++) {
        final cart = (await _cart(dio)).data!;
        expect((cart['items']! as List).cast<Json>().single['quantity'], 2);
        expect(cart['promotions'], hasLength(1));
      }
      // A second client of the same backend sees it too.
      final other = jsonDio(backend);
      expect((await _cart(other)).data!['items']! as List, hasLength(1));
    });

    test('T-0051-AC4: reset() clears every cart', () async {
      final p = _withStock(products, 2);
      await putQuantity(dio, p.id, 2);
      await putQuantity(dio, p.id, 1, user: collector);
      backend.reset();
      for (final user in [reader, collector]) {
        final cart = (await _cart(dio, user: user)).data!;
        expect(cart['items'], isEmpty, reason: user);
        expect(cart['totalCents'], 0);
      }
      // And the cart is usable again afterwards.
      expect((await putQuantity(dio, p.id, 1)).statusCode, 200);
    });

    test(
      'T-0051-AC4: another user\'s cart is never visible or touched',
      () async {
        final a = products.values.firstWhere((p) => p.stock >= 5);
        final b = products.values.lastWhere((p) => p.stock >= 5);
        expect(a.id, isNot(b.id));
        await putQuantity(dio, a.id, 3, user: reader);
        await putQuantity(dio, b.id, 2, user: collector);
        await applyCode(dio, 'SAVE10', user: reader);
        final mine = (await _cart(dio, user: reader)).data!;
        final theirs = (await _cart(dio, user: collector)).data!;
        expect((mine['items']! as List).cast<Json>().single['productId'], a.id);
        expect(
          (theirs['items']! as List).cast<Json>().single['productId'],
          b.id,
        );
        expect(mine['promotions'], hasLength(1));
        expect(theirs['promotions'], isEmpty, reason: 'codes are per user');
        // Removing one's own line leaves the other's alone.
        await putQuantity(dio, a.id, 0, user: reader);
        expect(
          (await _cart(dio, user: collector)).data!['items']! as List,
          hasLength(1),
        );
        expect(
          (await _cart(dio, user: reader)).data!['items']! as List,
          isEmpty,
        );
        // DELETE promo only clears the caller's.
        await applyCode(dio, 'SAVE25', user: collector);
        await putQuantity(dio, a.id, 1, user: reader);
        await applyCode(dio, 'SAVE10', user: reader);
        await call<Json>(
          dio,
          'DELETE',
          '/v1/me/cart/promo',
          headers: bearer(reader),
        );
        expect(
          (await _cart(dio, user: collector)).data!['promotions']! as List,
          hasLength(1),
        );
      },
    );

    test(
      'T-0051-AC4: the same user with a refreshed token keeps the cart',
      () async {
        final p = _withStock(products, 2);
        await putQuantity(dio, p.id, 2);
        final r = await call<Json>(
          dio,
          'GET',
          '/v1/me/cart',
          headers: bearer(reader, 7),
        );
        expect(r.data!['items']! as List, hasLength(1));
      },
    );

    test('T-0051-AC4: the empty store keeps its own carts, so no line names a missing product', () async {
      final p = _withStock(products, 2);
      await putQuantity(dio, p.id, 2);
      backend.useScenario('commerce.empty');
      expect((await _cart(dio)).data!['items']! as List, isEmpty);
      expect((await putQuantity(dio, p.id, 1)).statusCode, 404);
      backend.useScenario(null);
      expect((await _cart(dio)).data!['items']! as List, hasLength(1));
    });
  });
}
