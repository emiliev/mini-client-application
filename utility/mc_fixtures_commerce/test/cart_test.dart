import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';

import 'oracle.dart';
import 'support.dart';

const List<String> _allCodes = [
  'SAVE10',
  'SAVE25',
  'TAKE5',
  'TAKE15',
  'HEROES3',
  'COSMIC3',
];

/// A pure-function line for the direct pricing tests.
LineInput _line(int id, String category, int unit, int quantity) => LineInput(
  productId: id,
  title: 'P$id',
  categoryId: category,
  listCents: unit,
  unitCents: unit,
  quantity: quantity,
);

Promotion _promo(String code) => promotionFor(code)!;

/// The cart as the API serves it, as oracle input.
List<(ProductView, int)> _lines(Json cart, Map<int, ProductView> products) => [
  for (final item in (cart['items']! as List).cast<Json>())
    (products[item['productId']! as int]!, item['quantity']! as int),
];

List<String> _codes(Json cart) => [
  for (final p in (cart['promotions']! as List).cast<Json>())
    p['code']! as String,
];

/// Checks one served cart against the oracle, line by line and in total.
void _expectMatchesOracle(
  Json cart,
  Map<int, ProductView> products, {
  String? reason,
}) {
  final items = (cart['items']! as List).cast<Json>();
  final oracle = oracleCart(_lines(cart, products), _codes(cart));
  expect(
    [for (final i in items) i['totalCents']],
    oracle.lineTotals,
    reason: 'line totals; $reason',
  );
  expect(
    [for (final i in items) i['discountCents']],
    oracle.lineDiscounts,
    reason: 'line discounts; $reason',
  );
  expect(cart['totalCents'], oracle.total, reason: 'total; $reason');
  // P1-09 AC5: the total is the sum of the line totals after promotions.
  expect(
    cart['totalCents'],
    items.fold<int>(0, (a, i) => a + (i['totalCents']! as int)),
    reason: 'sum of lines; $reason',
  );
  final promotions = (cart['promotions']! as List).cast<Json>();
  for (final p in promotions) {
    expect(
      p['discountCents'],
      oracle.byCode[p['code']],
      reason: '${p['code']}; $reason',
    );
  }
}

void main() {
  group('T-0051-AC3 cart arithmetic', () {
    test('T-0051-AC3: 20 seeded carts: total = sum of line totals, equal to the oracle', () async {
      var withB2g1 = 0;
      var withPercent = 0;
      var withFixed = 0;
      var withAllThree = 0;
      for (var n = 0; n < 20; n++) {
        final seed = n < 14 ? 42 : 7;
        final dio = jsonDio(commerceBackend(seed: seed));
        final products = await loadProducts(dio);
        final rng = Random(5000 + n);
        // Carts lean on heroes and cosmic so that buy-2-get-1 has units to
        // work with.
        final pool = [
          ...inCategory(products, 'heroes'),
          ...inCategory(products, 'cosmic'),
          ...products.values.where((p) => p.stock >= 1),
        ];
        final chosen = <int>{};
        final lineCount = 1 + rng.nextInt(6);
        while (chosen.length < lineCount) {
          final p = pool[rng.nextInt(pool.length)];
          if (chosen.add(p.id)) {
            final quantity = 1 + rng.nextInt(min(p.stock, 6));
            final r = await putQuantity(dio, p.id, quantity);
            expect(r.statusCode, 200, reason: 'cart $n product ${p.id}');
            _expectMatchesOracle(r.data!, products, reason: 'cart $n');
          }
        }
        // Apply the codes in a seeded order; some are refused.
        final codes = [..._allCodes]..shuffle(rng);
        for (final code in codes) {
          final r = await applyCode(dio, code);
          if (r.statusCode == 200) {
            _expectMatchesOracle(r.data!, products, reason: 'cart $n +$code');
          } else {
            expect(r.statusCode, 409);
          }
        }
        final cart = (await getJson(dio, '/v1/me/cart', user: reader)).data!;
        _expectMatchesOracle(cart, products, reason: 'cart $n final');
        final byCode = {
          for (final p in (cart['promotions']! as List).cast<Json>())
            p['code']! as String: p['discountCents']! as int,
        };
        if ((byCode['HEROES3'] ?? 0) + (byCode['COSMIC3'] ?? 0) > 0) withB2g1++;
        if ((byCode['SAVE10'] ?? 0) + (byCode['SAVE25'] ?? 0) > 0) {
          withPercent++;
        }
        if ((byCode['TAKE5'] ?? 0) + (byCode['TAKE15'] ?? 0) > 0) withFixed++;
        if (byCode.values.where((v) => v > 0).length >= 3) withAllThree++;
      }
      // The sample is not vacuous: every promotion kind took something off
      // in several carts.
      expect(withB2g1, greaterThanOrEqualTo(3));
      expect(withPercent, greaterThanOrEqualTo(8));
      expect(withFixed, greaterThanOrEqualTo(3));
      expect(withAllThree, greaterThanOrEqualTo(1));
    });

    test('T-0051-AC3: the oracle itself is right on a worked example', () {
      // Heroes at 1000, 1000, 500 (qty 1 each) + SAVE10 + TAKE5.
      ProductView p(int id, int unit) => (
        id: id,
        title: 't',
        category: 'heroes',
        listCents: unit,
        unitCents: unit,
        stock: 9,
      );
      final r = oracleCart(
        [(p(1, 1000), 1), (p(2, 1000), 1), (p(3, 500), 1)],
        ['HEROES3', 'SAVE10', 'TAKE5'],
      );
      // Free third: 500. Percent: 10% of 1000, 1000, 0 = 100 + 100. Left:
      // 900 + 900 + 0 = 1800 < 2500, so TAKE5 takes nothing.
      expect(r.lineTotals, [900, 900, 0]);
      expect(r.byCode, {'HEROES3': 500, 'SAVE10': 200, 'TAKE5': 0});
    });
  });

  group('T-0051-AC3 promotions and the stacking order, pinned', () {
    test(
      'T-0051-AC3: buy-2-get-1 makes the cheapest of every three units free',
      () {
        final cart = priceCart(
          [_line(1, 'heroes', 900, 2), _line(2, 'heroes', 300, 1)],
          [_promo('HEROES3')],
        );
        expect(cart.lines.map((l) => l.buyTwoGetOneCents), [0, 300]);
        expect(cart.totalCents, 1800);
        // Six units, dearest first in groups of three (900 900 900 | 300 300
        // 300): the last of each group is free.
        final six = priceCart(
          [_line(1, 'heroes', 900, 3), _line(2, 'heroes', 300, 3)],
          [_promo('HEROES3')],
        );
        expect(six.lines.map((l) => l.buyTwoGetOneCents), [900, 300]);
        // Seven units: the seventh is paid.
        final seven = priceCart(
          [_line(1, 'heroes', 900, 4), _line(2, 'heroes', 300, 3)],
          [_promo('HEROES3')],
        );
        expect(seven.lines.map((l) => l.buyTwoGetOneCents), [900, 300]);
        // Two units: nothing free, and the code is not eligible.
        final two = priceCart(
          [_line(1, 'heroes', 900, 2)],
          [_promo('HEROES3')],
        );
        expect(two.discountCents, 0);
        expect(two.promotions.single.eligible, isFalse);
      },
    );

    test('T-0051-AC3: buy-2-get-1 only counts its own category', () {
      final cart = priceCart(
        [_line(1, 'heroes', 900, 2), _line(2, 'cosmic', 300, 1)],
        [_promo('HEROES3')],
      );
      expect(cart.discountCents, 0);
      final both = priceCart(
        [_line(1, 'heroes', 900, 2), _line(2, 'cosmic', 300, 1)],
        [_promo('HEROES3'), _promo('COSMIC3')],
      );
      expect(both.discountCents, 0);
    });

    test('T-0051-AC3: buy-2-get-1 ties go to the earlier line', () {
      final cart = priceCart(
        [_line(1, 'heroes', 500, 2), _line(2, 'heroes', 500, 1)],
        [_promo('HEROES3')],
      );
      expect(cart.lines.map((l) => l.buyTwoGetOneCents), [0, 500]);
    });

    test('T-0051-AC3: percent-off takes its share of every line, rounded half-up per line', () {
      // 10% of 495 is 49.5 -> 50; of 705 is 70.5 -> 71 (half-even would
      // give 70); each line on its own, so 121, not 120 for 1200.
      final cart = priceCart(
        [_line(1, 'heroes', 495, 1), _line(2, 'villains', 705, 1)],
        [_promo('SAVE10')],
      );
      expect(cart.lines.map((l) => l.percentCents), [50, 71]);
      expect(cart.discountCents, 121);
      expect(cart.totalCents, 1200 - 121);
      // 25% of 2 is 0.5 -> 1: the smallest cents round up.
      final tiny = priceCart([_line(1, 'heroes', 2, 1)], [_promo('SAVE25')]);
      expect(tiny.discountCents, 1);
      // 10% of 4 is 0.4 -> 0.
      final below = priceCart([_line(1, 'heroes', 4, 1)], [_promo('SAVE10')]);
      expect(below.discountCents, 0);
    });

    test('T-0051-AC3: fixed-off needs its minimum, reached or exceeded', () {
      PricedCart at(int cents) =>
          priceCart([_line(1, 'heroes', cents, 1)], [_promo('TAKE5')]);
      expect(at(2499).discountCents, 0);
      expect(at(2499).promotions.single.eligible, isFalse);
      expect(at(2500).discountCents, 500);
      expect(at(2500).totalCents, 2000);
      expect(at(2500).promotions.single.eligible, isTrue);
      // The dearer code has its own minimum.
      PricedCart dear(int cents) =>
          priceCart([_line(1, 'heroes', cents, 1)], [_promo('TAKE15')]);
      expect(dear(7999).discountCents, 0);
      expect(dear(8000).discountCents, 1500);
    });

    test('T-0051-AC3: fixed-off is checked against what is left after the earlier steps', () {
      // A 3000 line, SAVE25 -> 2250 < 2500: only the percent takes effect.
      final cart = priceCart(
        [_line(1, 'heroes', 3000, 1)],
        [_promo('SAVE25'), _promo('TAKE5')],
      );
      expect(cart.beforeFixedCents, 2250);
      expect(cart.discountCents, 750, reason: 'only the percent took effect');
      final big = priceCart([_line(1, 'heroes', 8000, 1)], [_promo('TAKE15')]);
      expect(big.totalCents, 6500);
    });

    test('T-0051-AC3: the fixed amount is shared by what is left, the odd cents to the largest remainders', () {
      final cart = priceCart(
        [
          _line(1, 'heroes', 1000, 1),
          _line(2, 'heroes', 1000, 1),
          _line(3, 'heroes', 1000, 1),
        ],
        [_promo('TAKE5')],
      );
      // 500 / 3 = 166 each, 2 cents over: all remainders tie, so the first
      // two lines take them.
      expect(cart.lines.map((l) => l.fixedCents), [167, 167, 166]);
      expect(cart.discountCents, 500);
      // Unequal lines: 500 of 3000 over 2000 + 1000 = 333.33 + 166.67 ->
      // 333 + 166 + 1 spare to the larger remainder (second line).
      final unequal = priceCart(
        [_line(1, 'heroes', 2000, 1), _line(2, 'heroes', 1000, 1)],
        [_promo('TAKE5')],
      );
      expect(unequal.lines.map((l) => l.fixedCents), [333, 167]);
    });

    test('T-0051-AC3: the stacking order is buy-2-get-1, then percent, then fixed, whatever the order the codes are applied in', () {
      final lines = [
        _line(1, 'heroes', 1000, 1),
        _line(2, 'heroes', 1000, 1),
        _line(3, 'heroes', 500, 1),
        _line(4, 'villains', 4000, 1),
      ];
      final expected = priceCart(lines, [
        _promo('HEROES3'),
        _promo('SAVE10'),
        _promo('TAKE5'),
      ]);
      // Step 2 frees the 500; step 3 takes 10% of what is left of each line
      // (100, 100, 0, 400 = 600); step 4 has 6500 - 500 - 600 = 5400 >= 2500.
      expect(expected.lines.map((l) => l.buyTwoGetOneCents), [0, 0, 500, 0]);
      expect(expected.lines.map((l) => l.percentCents), [100, 100, 0, 400]);
      expect(expected.beforeFixedCents, 5400);
      expect(expected.discountCents, 500 + 600 + 500);
      expect(expected.totalCents, 6500 - 1600);
      // Percent on the whole subtotal first would give 650; after the free
      // unit it gives 600. A fixed amount before the percent would change
      // the percent base.
      for (final order in [
        ['TAKE5', 'SAVE10', 'HEROES3'],
        ['SAVE10', 'TAKE5', 'HEROES3'],
        ['SAVE10', 'HEROES3', 'TAKE5'],
        ['TAKE5', 'HEROES3', 'SAVE10'],
      ]) {
        final other = priceCart(lines, [for (final c in order) _promo(c)]);
        expect(other.totalCents, expected.totalCents, reason: '$order');
        expect(
          other.lines.map((l) => l.totalCents),
          expected.lines.map((l) => l.totalCents),
          reason: '$order',
        );
      }
    });

    test('T-0051-AC3: the fixed minimum is checked after the percent step', () {
      // 2600 passes TAKE5's minimum on its own, but not after 25% off.
      final alone = priceCart([_line(1, 'heroes', 2600, 1)], [_promo('TAKE5')]);
      expect(alone.discountCents, 500);
      final stacked = priceCart(
        [_line(1, 'heroes', 2600, 1)],
        [_promo('TAKE5'), _promo('SAVE25')],
      );
      expect(stacked.beforeFixedCents, 1950);
      expect(stacked.promotions.first.eligible, isFalse);
      expect(stacked.discountCents, 650);
    });

    test('T-0051-AC3: each promotion code is worth the documented amount through the API', () async {
      final dio = jsonDio(commerceBackend());
      final products = await loadProducts(dio);
      final heroes = inCategory(
        products,
        'heroes',
        minStock: 3,
      ).where((p) => p.listCents == p.unitCents).take(3).toList();
      // Three heroes, one unit each: the cheapest is free.
      for (final p in heroes) {
        await putQuantity(dio, p.id, 1);
      }
      final r = await applyCode(dio, 'heroes3');
      expect(r.statusCode, 200);
      final cheapest = heroes.map((p) => p.unitCents).reduce(min);
      expect(r.data!['discountCents'], cheapest);
      expect(
        r.data!['totalCents'],
        heroes.fold<int>(0, (a, p) => a + p.unitCents) - cheapest,
      );
      final promo = (r.data!['promotions']! as List).single as Json;
      expect(promo, {
        'code': 'HEROES3',
        'kind': 'buy_2_get_1',
        'title': 'Buy 2 get 1 on Heroes',
        'eligible': true,
        'discountCents': cheapest,
      });
    });
  });

  group('T-0051-AC3 cart lines', () {
    test('T-0051-AC3: a line holds the quantity it was last set to; 0 removes it; lines keep their order', () async {
      final dio = jsonDio(commerceBackend());
      final products = await loadProducts(dio);
      final ids = inCategory(
        products,
        'cosmic',
        minStock: 5,
      ).take(3).map((p) => p.id).toList();
      for (final id in ids) {
        await putQuantity(dio, id, 1);
      }
      var cart = (await putQuantity(dio, ids[0], 4)).data!;
      List<int> idsOf(Json c) => [
        for (final i in (c['items']! as List).cast<Json>())
          i['productId']! as int,
      ];
      expect(idsOf(cart), ids, reason: 'a changed line keeps its place');
      expect((cart['items']! as List).cast<Json>().first['quantity'], 4);
      expect(cart['itemCount'], 6);
      cart = (await putQuantity(dio, ids[1], 0)).data!;
      expect(idsOf(cart), [ids[0], ids[2]]);
      expect(cart['itemCount'], 5);
      // Removing a line that is not there is harmless.
      expect((await putQuantity(dio, ids[1], 0)).statusCode, 200);
      cart = (await getJson(dio, '/v1/me/cart', user: reader)).data!;
      expect(idsOf(cart), [ids[0], ids[2]]);
    });

    test(
      'T-0051-AC3: an empty cart is all zeros, and emptying it drops its codes',
      () async {
        final dio = jsonDio(commerceBackend());
        final empty = (await getJson(dio, '/v1/me/cart', user: reader)).data!;
        expect(empty, {
          'currency': 'EUR',
          'items': <Object?>[],
          'itemCount': 0,
          'promotions': <Object?>[],
          'subtotalCents': 0,
          'discountCents': 0,
          'totalCents': 0,
        });
        final products = await loadProducts(dio);
        final p = inCategory(products, 'heroes').first;
        await putQuantity(dio, p.id, 1);
        expect((await applyCode(dio, 'SAVE10')).statusCode, 200);
        final cleared = (await putQuantity(dio, p.id, 0)).data!;
        expect(cleared['promotions'], isEmpty);
        await putQuantity(dio, p.id, 1);
        expect(
          ((await getJson(
                dio,
                '/v1/me/cart',
                user: reader,
              )).data!['promotions']!
              as List),
          isEmpty,
          reason: 'the code does not come back',
        );
      },
    );

    test('T-0051-AC3: a deal product is charged at its deal price', () async {
      final dio = jsonDio(commerceBackend());
      final deal =
          ((await getJson(dio, '/v1/store/deals')).data!['deals']! as List)
              .cast<Json>()
              .first;
      final product = deal['product']! as Json;
      final cart = (await putQuantity(dio, product['id']! as int, 3)).data!;
      final line = (cart['items']! as List).single as Json;
      expect(line['unitPriceCents'], deal['dealPriceCents']);
      expect(line['listPriceCents'], deal['originalPriceCents']);
      expect(line['subtotalCents'], 3 * (deal['dealPriceCents']! as int));
      expect(cart['totalCents'], 3 * (deal['dealPriceCents']! as int));
    });

    test('T-0051-AC3: removing codes one at a time or all at once', () async {
      final dio = jsonDio(commerceBackend());
      final products = await loadProducts(dio);
      for (final p in inCategory(products, 'heroes', minStock: 5).take(3)) {
        await putQuantity(dio, p.id, 5);
      }
      for (final c in ['SAVE10', 'HEROES3', 'TAKE5']) {
        expect((await applyCode(dio, c)).statusCode, 200, reason: c);
      }
      var cart = (await call<Json>(
        dio,
        'DELETE',
        '/v1/me/cart/promo?code=save10',
        headers: bearer(reader),
      )).data!;
      expect(_codes(cart), ['HEROES3', 'TAKE5']);
      _expectMatchesOracle(cart, products);
      cart = (await call<Json>(
        dio,
        'DELETE',
        '/v1/me/cart/promo',
        headers: bearer(reader),
      )).data!;
      expect(cart['promotions'], isEmpty);
      expect(cart['discountCents'], 0);
      expect(cart['totalCents'], cart['subtotalCents']);
    });
  });
}
