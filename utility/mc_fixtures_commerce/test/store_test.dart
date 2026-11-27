import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';

import 'support.dart';

const List<String> _sectionPaths = [
  '/v1/store/banners',
  '/v1/store/deals',
  '/v1/store/categories',
  '/v1/store/categories/heroes/products',
  '/v1/store/categories/heroes/products?offset=20&limit=7',
  '/v1/store/featured',
];

Future<String> _text(
  Dio dio,
  String method,
  String path, {
  Object? body,
}) async {
  final r = await call<String>(
    dio,
    method,
    path,
    body: body,
    headers: bearer(reader),
  );
  return '${r.statusCode} ${r.data}';
}

void main() {
  group('T-0051-AC1 determinism', () {
    test(
      'T-0051-AC1: the same requests give byte-identical bodies (seed 42)',
      () async {
        // Two independent backends, each served the same session of requests.
        Future<List<String>> session() async {
          final dio = plainDio(commerceBackend());
          return [
            for (final path in _sectionPaths) await _text(dio, 'GET', path),
            await _text(dio, 'GET', '/v1/me/cart'),
            await _text(
              dio,
              'PUT',
              '/v1/me/cart/items/500060',
              body: {'quantity': 2},
            ),
            await _text(
              dio,
              'POST',
              '/v1/me/cart/promo',
              body: {'code': 'SAVE10'},
            ),
            await _text(dio, 'GET', '/v1/me/cart'),
            await _text(
              dio,
              'PUT',
              '/v1/me/cart/items/500060',
              body: {'quantity': 0},
            ),
            await _text(dio, 'DELETE', '/v1/me/cart/promo'),
          ];
        }

        final a = await session();
        final b = await session();
        expect(a, b);
        expect(a.first, startsWith('200 '));
        // The product ids in the bodies are the same on every run of the
        // process too (a pinned fact, not only equality of two runs).
        expect(a[5], contains('"id":501740'));
      },
    );

    test('T-0051-AC1: a different seed changes prices and stock, not ids or titles', () async {
      Future<Json> categoryPage(int seed) async => (await getJson(
        jsonDio(commerceBackend(seed: seed)),
        '/v1/store/categories/heroes/products?limit=100',
      )).data!;
      final a = await categoryPage(42);
      final b = await categoryPage(7);
      List<Object?> field(Json page, String k) => [
        for (final p in (page['results']! as List).cast<Json>()) p[k],
      ];
      expect(field(a, 'id'), field(b, 'id'));
      expect(field(a, 'title'), field(b, 'title'));
      expect(field(a, 'priceCents'), isNot(field(b, 'priceCents')));
    });

    test('T-0051-AC1: no clock or counter leaks into a body (ends-at is the fixed clock)', () async {
      final deals =
          (await getJson(
                jsonDio(commerceBackend()),
                '/v1/store/deals',
              )).data!['deals']!
              as List;
      expect(deals, hasLength(8));
      expect((deals.first as Json)['endsAt'], '2026-01-02T00:00:00.000Z');
      expect((deals.last as Json)['endsAt'], '2026-01-09T00:00:00.000Z');
    });
  });

  group('T-0051-AC2 sections work on their own', () {
    late Dio dio;
    setUp(() => dio = jsonDio(commerceBackend()));

    test(
      'T-0051-AC2: banners are 3 to 5, each with a target of a known kind',
      () async {
        final banners =
            ((await getJson(dio, '/v1/store/banners')).data!['banners']!
                    as List)
                .cast<Json>();
        expect(banners.length, inInclusiveRange(3, 5));
        final kinds = <String>{};
        for (final b in banners) {
          expect(b['title'], isNotEmpty);
          expect(b['subtitle'], isNotEmpty);
          expect((b['image']! as Json)['path'], startsWith('mock-asset://'));
          final target = b['target']! as Json;
          kinds.add(target['type']! as String);
          switch (target['type']) {
            case 'comic':
              expect(target['comicId'], isA<int>());
            case 'category':
              expect(
                categoryDefs.map((c) => c.id),
                contains(target['categoryId']),
              );
            case 'search':
              expect(target['query'], isNotEmpty);
            default:
              fail('unknown target ${target['type']}');
          }
        }
        expect(kinds, {'comic', 'category', 'search'});
      },
    );

    test(
      'T-0051-AC2: deals show the original and the deal price, both in cents',
      () async {
        final deals =
            ((await getJson(dio, '/v1/store/deals')).data!['deals']! as List)
                .cast<Json>();
        expect(deals.map((d) => d['discountPercent']), dealPercents);
        for (final d in deals) {
          final original = d['originalPriceCents']! as int;
          final deal = d['dealPriceCents']! as int;
          final pct = d['discountPercent']! as int;
          expect(deal, lessThan(original));
          // Independent check of the documented rounding: the discount is
          // original * pct / 100, half-up.
          final exact2 = original * pct * 2; // in half-cents x 100
          final discount = (exact2 + 100) ~/ 200;
          expect(original - deal, discount, reason: '$d');
          expect(d['currency'], 'EUR');
          expect((d['product']! as Json)['stock'], greaterThan(0));
        }
      },
    );

    test('T-0051-AC2: categories list name, count and image; counts add up to the products', () async {
      final cats =
          ((await getJson(dio, '/v1/store/categories')).data!['categories']!
                  as List)
              .cast<Json>();
      expect(cats.map((c) => c['id']), categoryDefs.map((c) => c.id));
      var sum = 0;
      for (final c in cats) {
        expect(c['name'], isNotEmpty);
        expect((c['image']! as Json)['path'], startsWith('mock-asset://'));
        final page = (await getJson(
          dio,
          '/v1/store/categories/${c['id']}/products?limit=1',
        )).data!;
        expect(c['count'], page['total']);
        sum += c['count']! as int;
      }
      expect(sum, 120 * issuesSold);
    });

    test('T-0051-AC2: featured returns 6 products', () async {
      final featured =
          ((await getJson(dio, '/v1/store/featured')).data!['products']!
                  as List)
              .cast<Json>();
      expect(featured, hasLength(6));
      expect(featured.every((p) => (p['stock']! as int) > 0), isTrue);
    });

    test('T-0051-AC2: every section answers 200 with its own key', () async {
      for (final (path, key) in const [
        ('/v1/store/banners', 'banners'),
        ('/v1/store/deals', 'deals'),
        ('/v1/store/categories', 'categories'),
        ('/v1/store/featured', 'products'),
        ('/v1/store/categories/cosmic/products', 'results'),
      ]) {
        final r = await getJson(dio, path);
        expect(r.statusCode, 200, reason: path);
        expect(r.data!.keys, contains(key), reason: path);
      }
    });

    for (final section in commerceSections.entries) {
      final scenario = 'store.${section.key}_error';
      test('T-0051-AC2: $scenario fails its routes and nothing else', () async {
        final backend = commerceBackend()..useScenario(scenario);
        final dio = jsonDio(backend);
        const probes = <(String, String, Object?)>[
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
        // The routes of the section, matched by method and pattern.
        bool inSection(String method, String path) => section.value.any((r) {
          final [m, pattern] = r.split(' ');
          final regex = RegExp(
            '^${pattern.replaceAll(RegExp(r':\w+'), r'[^/]+')}\$',
          );
          return m == method && regex.hasMatch(path);
        });
        var failed = 0;
        for (final (method, path, body) in probes) {
          final r = await call<Json>(
            dio,
            method,
            path,
            body: body,
            headers: bearer(reader),
          );
          if (inSection(method, path)) {
            failed++;
            expect(r.statusCode, 500, reason: '$method $path');
            expect(r.data!['error'], containsPair('code', 'injected_failure'));
          } else {
            expect(r.statusCode, isNot(500), reason: '$method $path');
            expect(r.statusCode, lessThan(500), reason: '$method $path');
          }
        }
        expect(failed, section.value.length);
        // Switching it off restores the section.
        backend.useScenario(null);
        expect((await getJson(dio, '/v1/store/deals')).statusCode, 200);
      });
    }

    test('T-0051-AC2: only the deals route fails with store.deals_error; the others render', () async {
      final backend = commerceBackend()..useScenario('store.deals_error');
      final dio = jsonDio(backend);
      expect((await getJson(dio, '/v1/store/deals')).statusCode, 500);
      for (final path in const [
        '/v1/store/banners',
        '/v1/store/categories',
        '/v1/store/featured',
      ]) {
        expect((await getJson(dio, path)).statusCode, 200, reason: path);
      }
    });
  });

  group('T-0051-AC2 the documented facts of the default set', () {
    test('T-0051-AC2: stock, deals and featured sit at the positions CONTRACT.md names', () async {
      final dio = jsonDio(commerceBackend());
      final products = await loadProducts(dio);
      // The catalogue in comic title order: issues 1 to 3 of every series.
      final order = [
        for (final c in ComicUniverse(42).byTitle)
          if (c.issueNumber <= 3) c.id,
      ];
      expect(order, hasLength(360));
      expect(products.keys.toSet(), order.toSet());
      for (var k = 0; k < order.length; k++) {
        final stock = products[order[k]]!.stock;
        if (k % 11 == 5) {
          expect(stock, 0, reason: 'position $k is sold out');
        } else if (k % 7 == 0) {
          expect(stock, 120, reason: 'position $k has plenty');
        } else {
          expect(stock, inInclusiveRange(3, 40), reason: 'position $k');
        }
        expect(products[order[k]]!.listCents, inInclusiveRange(299, 1999));
      }
      final deals =
          ((await getJson(dio, '/v1/store/deals')).data!['deals']! as List)
              .cast<Json>();
      expect(
        [for (final d in deals) (d['product']! as Json)['id']],
        [
          for (final k in const [7, 48, 89, 130, 171, 212, 253, 294]) order[k],
        ],
      );
      final featured =
          ((await getJson(dio, '/v1/store/featured')).data!['products']!
                  as List)
              .cast<Json>();
      expect(
        [for (final p in featured) p['id']],
        [
          for (final k in const [3, 56, 109, 162, 215, 268]) order[k],
        ],
      );
      expect(order.first, 500060, reason: 'Amber Chronicles #1 is first');
    });
  });

  test(
    'T-0051-AC2: a product category follows the comics series id base',
    () async {
      final products = await loadProducts(jsonDio(commerceBackend()));
      final series = {
        for (final c in ComicUniverse(42).byTitle) c.id: c.seriesId,
      };
      for (final p in products.values) {
        expect(
          categoryDefs[(series[p.id]! - seriesIdBase) % categoryDefs.length].id,
          p.category,
        );
      }
    },
  );

  group('T-0051-AC2 category paging', () {
    test('T-0051-AC2: paging is stable and total for every category and several page sizes', () async {
      final dio = jsonDio(commerceBackend());
      for (final category in categoryDefs) {
        final all = (await getJson(
          dio,
          '/v1/store/categories/${category.id}/products?limit=100',
        )).data!;
        final expectedIds = [
          for (final p in (all['results']! as List).cast<Json>()) p['id'],
        ];
        final total = all['total']! as int;
        expect(expectedIds, hasLength(total));
        expect(expectedIds.toSet(), hasLength(total), reason: 'no repeats');
        for (final limit in [1, 7, 20, 33, 60]) {
          final seen = <Object?>[];
          for (var offset = 0; ; offset += limit) {
            final page = (await getJson(
              dio,
              '/v1/store/categories/${category.id}/products'
              '?offset=$offset&limit=$limit',
            )).data!;
            expect(page['total'], total);
            expect(page['offset'], offset);
            expect(page['limit'], limit);
            final results = (page['results']! as List).cast<Json>();
            expect(page['count'], results.length);
            if (results.isEmpty) {
              break;
            }
            seen.addAll(results.map((p) => p['id']));
          }
          expect(seen, expectedIds, reason: '${category.id} at limit $limit');
        }
        // Asking again gives the same page (stable).
        final again = (await getJson(
          dio,
          '/v1/store/categories/${category.id}/products?limit=100',
        )).data!;
        expect(again, all);
      }
    });

    test(
      'T-0051-AC2: a page past the end is empty, with the total kept',
      () async {
        final dio = jsonDio(commerceBackend());
        final page = (await getJson(
          dio,
          '/v1/store/categories/villains/products?offset=500',
        )).data!;
        expect(page['count'], 0);
        expect(page['results'], isEmpty);
        expect(page['total'], 60);
      },
    );

    test(
      'T-0051-AC2: the default page is 20 and products belong to the category',
      () async {
        final dio = jsonDio(commerceBackend());
        final page = (await getJson(
          dio,
          '/v1/store/categories/mystery/products',
        )).data!;
        expect(page['limit'], 20);
        expect(page['count'], 20);
        expect(
          (page['results']! as List).cast<Json>().every(
            (p) => p['categoryId'] == 'mystery',
          ),
          isTrue,
        );
      },
    );
  });
}
