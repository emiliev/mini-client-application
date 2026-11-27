import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';

import 'support.dart';

/// Every problem of a decoded JSON value with money: a key that names money
/// but does not end in `Cents`, or a `...Cents` value that is not an int.
List<String> moneyProblems(Object? value, [String path = r'$']) {
  final problems = <String>[];
  if (value is Map) {
    // A page's `total` counts matches; it is not money.
    final isPage = value.containsKey('results');
    for (final MapEntry(:key, :value) in value.entries) {
      final at = '$path.$key';
      final k = (key as String).toLowerCase();
      final namesMoney =
          k.contains('price') ||
          k.contains('total') ||
          k.contains('amount') ||
          k.contains('discount') && !k.contains('percent');
      if (namesMoney && !key.endsWith('Cents') && !(isPage && k == 'total')) {
        problems.add('$at names money but does not end in Cents');
      }
      if (key.endsWith('Cents') && value != null && value is! int) {
        problems.add('$at is ${value.runtimeType}, not int');
      }
      problems.addAll(moneyProblems(value, at));
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      problems.addAll(moneyProblems(value[i], '$path[$i]'));
    }
  }
  return problems;
}

/// Source lines of [text] that could put a floating point number on a money
/// path: the types, rounding or division of doubles, and decimal literals.
List<String> floatingPointHits(String text) {
  final hits = <String>[];
  final forbidden = <String, RegExp>{
    'double': RegExp(r'\bdouble\b'),
    'num': RegExp(r'\bnum\b'),
    'toDouble': RegExp(r'\.toDouble\b'),
    'rounding call': RegExp(
      r'\.(round|floor|ceil|truncate|toStringAsFixed|roundToDouble)\b',
    ),
    'nextDouble': RegExp(r'\bnextDouble\b'),
    'decimal literal': RegExp(r'(?<![\w.])\d+\.\d+(?![\w.])'),
    'division': RegExp(r'(?<![/~*])\s/\s(?!/)'),
    'dart:math': RegExp('dart:math'),
  };
  for (final (n, line) in text.split('\n').indexed) {
    final code = line.trimLeft().startsWith('//')
        ? ''
        : line.replaceAll(RegExp(r"'[^']*'"), "''");
    for (final MapEntry(:key, :value) in forbidden.entries) {
      if (value.hasMatch(code)) {
        hits.add('line ${n + 1}: $key: ${line.trim()}');
      }
    }
  }
  return hits;
}

Directory _libSrc() {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null)
      '$srcDir/$workspace/utility/mc_fixtures_commerce/lib/src',
    'utility/mc_fixtures_commerce/lib/src',
  ]) {
    if (Directory(candidate).existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError('lib/src not found from ${Directory.current}');
}

void main() {
  group('T-0051-AC3 money is integer cents', () {
    test('T-0051-AC3: every money value of every response is an int and every money key ends in Cents', () async {
      final dio = plainDio(commerceBackend());
      final products = await loadProducts(jsonDio(commerceBackend()));
      final heroes = inCategory(products, 'heroes', minStock: 3);
      final texts = <String>[];
      Future<void> take(String method, String path, [Object? body]) async {
        final r = await call<String>(
          dio,
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        texts.add(r.data!);
      }

      for (final path in const [
        '/v1/store/banners',
        '/v1/store/deals',
        '/v1/store/categories',
        '/v1/store/categories/heroes/products?limit=100',
        '/v1/store/categories/cosmic/products?limit=100',
        '/v1/store/featured',
      ]) {
        await take('GET', path);
      }
      for (final p in heroes.take(4)) {
        await take('PUT', '/v1/me/cart/items/${p.id}', {'quantity': 3});
      }
      for (final code in ['HEROES3', 'SAVE25', 'TAKE5']) {
        await take('POST', '/v1/me/cart/promo', {'code': code});
      }
      await take('GET', '/v1/me/cart');
      expect(texts, hasLength(6 + 4 + 3 + 1));
      var moneyValues = 0;
      for (final text in texts) {
        expect(moneyProblems(jsonDecode(text)), isEmpty);
        // The wire text has no decimal point after a Cents key either (a
        // 5.0 would decode as a double; this catches a 5.00 too).
        expect(RegExp(r'Cents":-?\d+[.eE]').hasMatch(text), isFalse);
        moneyValues += RegExp(r'Cents":-?\d+').allMatches(text).length;
      }
      expect(moneyValues, greaterThan(200), reason: 'the scan is not vacuous');
    });

    test('T-0051-AC3: the scanner finds a double, a mis-named money key and a stray decimal (negative controls)', () {
      expect(moneyProblems({'totalCents': 12.5}), hasLength(1));
      expect(moneyProblems(jsonDecode('{"priceCents": 5.0}')), hasLength(1));
      expect(
        moneyProblems({
          'items': [
            {'unitPriceCents': '5'},
          ],
        }),
        hasLength(1),
      );
      expect(moneyProblems({'total': 5}), hasLength(1));
      expect(moneyProblems({'total': 5, 'results': <int>[]}), isEmpty);
      expect(moneyProblems({'price': 5}), hasLength(1));
      expect(moneyProblems({'discountPercent': 10, 'totalCents': 5}), isEmpty);
      expect(floatingPointHits('final x = 1.5;'), hasLength(1));
      expect(floatingPointHits('double x = 1;'), hasLength(1));
      expect(floatingPointHits('final y = a / b;'), hasLength(1));
      expect(floatingPointHits('final y = a ~/ b;'), isEmpty);
      expect(floatingPointHits('final y = x.round();'), hasLength(1));
      expect(floatingPointHits('final n = rng.nextDouble();'), hasLength(1));
      expect(floatingPointHits("const s = 'a / b 1.5';"), isEmpty);
      expect(floatingPointHits('/// 1.5 and double in a comment'), isEmpty);
    });

    test('T-0051-AC3: no source file of the package uses a double, a rounding call or a division', () {
      final files = _libSrc()
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(6));
      for (final file in files) {
        expect(
          floatingPointHits(file.readAsStringSync()),
          isEmpty,
          reason: file.path,
        );
      }
    });

    test('T-0051-AC3: the documented rounding is half-up, on the line, in integers', () {
      // cents * percent / 100: the half-cent rounds up; below it rounds down.
      const table = <(int cents, int percent, int expected)>[
        (495, 10, 50), // 49.5
        (705, 10, 71), // 70.5 (half-even would say 70)
        (494, 10, 49), // 49.4
        (496, 10, 50), // 49.6
        (2, 25, 1), // 0.5
        (1, 25, 0), // 0.25
        (3, 25, 1), // 0.75
        (0, 10, 0),
        (10, 10, 1),
        (999999, 25, 250000), // 249999.75
        (5, 50, 3), // 2.5
        (7, 50, 4), // 3.5
        (199, 15, 30), // 29.85
        (333, 15, 50), // 49.95
        (230, 15, 35), // 34.5
      ];
      for (final (cents, percent, expected) in table) {
        expect(
          percentOfHalfUp(cents, percent),
          expected,
          reason: '$cents x $percent%',
        );
      }
      // Per line: two half-cent lines round up each, so 121 and not the 120
      // that rounding the 1200 total would give.
      final cart = priceCart(
        [
          LineInput(
            productId: 1,
            title: 'a',
            categoryId: 'heroes',
            listCents: 495,
            unitCents: 495,
            quantity: 1,
          ),
          LineInput(
            productId: 2,
            title: 'b',
            categoryId: 'heroes',
            listCents: 705,
            unitCents: 705,
            quantity: 1,
          ),
        ],
        [promotionFor('SAVE10')!],
      );
      expect(cart.discountCents, 121);
      // The quantity is part of the line: 3 x 495 = 1485 -> 148.5 -> 149.
      final three = priceCart(
        [
          LineInput(
            productId: 1,
            title: 'a',
            categoryId: 'heroes',
            listCents: 495,
            unitCents: 495,
            quantity: 3,
          ),
        ],
        [promotionFor('SAVE10')!],
      );
      expect(three.discountCents, 149);
    });

    test(
      'T-0051-AC3: the deal price is the list price minus the half-up discount',
      () async {
        for (final seed in [42, 7, 1234]) {
          final deals =
              ((await getJson(
                        jsonDio(commerceBackend(seed: seed)),
                        '/v1/store/deals',
                      )).data!['deals']!
                      as List)
                  .cast<Json>();
          for (final d in deals) {
            final original = d['originalPriceCents']! as int;
            final pct = d['discountPercent']! as int;
            expect(
              d['dealPriceCents'],
              original - percentOfHalfUp(original, pct),
            );
          }
        }
      },
    );

    test(
      'T-0051-AC3: a full cart of 99 units of the dearest line stays exact',
      () async {
        final dio = jsonDio(commerceBackend());
        final products = await loadProducts(dio);
        final plenty = products.values.where((p) => p.stock >= 99).toList()
          ..sort((a, b) => b.unitCents.compareTo(a.unitCents));
        final p = plenty.first;
        final cart = (await putQuantity(dio, p.id, 99)).data!;
        expect(cart['subtotalCents'], 99 * p.unitCents);
        expect(cart['totalCents'], 99 * p.unitCents);
      },
    );
  });
}
