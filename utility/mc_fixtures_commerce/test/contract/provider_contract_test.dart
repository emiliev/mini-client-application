import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import '../support.dart';
import 'snapshot_cases.dart';

/// The package directory in the test's runfiles (Bazel) or the checkout.
Directory _dir(String relative) {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null) '$srcDir/$workspace/$relative',
    relative,
  ]) {
    if (Directory(candidate).existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError('$relative not found from ${Directory.current}');
}

ApiImage _image(Object? json) =>
    ApiImage.fromJson((json! as Map).cast<String, Object?>());

/// The statuses the snapshots must show (every other case is a 200).
const Map<String, int> _expectedStatus = {
  'category_invalid_limit': 400,
  'category_unknown': 404,
  'deals_error': 500,
  'expired_token': 401,
  'invalid_body': 400,
  'invalid_quantity': 400,
  'out_of_stock_over': 409,
  'out_of_stock_sold_out': 409,
  'promo_already_applied': 409,
  'promo_empty_cart': 409,
  'promo_kind_already_applied': 409,
  'promo_minimum_not_met': 409,
  'promo_no_matching_items': 409,
  'promo_not_applied': 409,
  'unauthenticated': 401,
  'unknown_product': 404,
  'unknown_promo': 404,
};

void main() {
  final commerce = _dir('utility/mc_fixtures_commerce');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0051-AC5 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0051-AC5: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${commerce.path}/test/contract/snapshots/${entry.key}.json',
        );
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
        final expected = jsonDecode(file.readAsStringSync());
        final actual = await runSnapshotCase(entry.value);
        expect(
          canonicalJson(actual),
          canonicalJson(expected),
          reason:
              'Contract drift in ${entry.key}. If intended, rerun '
              'tool/update_snapshots.dart and update CONTRACT.md.',
        );
        expect(
          actual['status'],
          _expectedStatus[entry.key] ?? 200,
          reason: 'the case no longer shows what its name says',
        );
      });
    }

    test('T-0051-AC5: no snapshot file lacks a case', () {
      final files = Directory('${commerce.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test('T-0051-AC5: every route, error code and promotion kind has a snapshot', () {
      final requests = [
        for (final c in snapshotCases.values) '${c.method} ${c.path}',
      ];
      for (final route in commerceRouteManifest) {
        final method = route.split(' ').first;
        final pattern = RegExp(
          '^$method ${route.split(' ').last.replaceAll(':id', r'[a-z-]+').replaceAll(':productId', r'\d+')}(\\?.*)?\$',
        );
        expect(requests.any(pattern.hasMatch), isTrue, reason: route);
      }
      final bodies = [
        for (final f in Directory(
          '${commerce.path}/test/contract/snapshots',
        ).listSync().whereType<File>())
          f.readAsStringSync(),
      ].join();
      for (final code in const [
        'unauthenticated',
        'unknown_product',
        'out_of_stock',
        'invalid_quantity',
        'invalid_body',
        'unknown_promo',
        'promo_not_applicable',
        'unknown_category',
        'invalid_parameter',
        'injected_failure',
      ]) {
        expect(bodies, contains('"code": "$code"'), reason: code);
      }
      for (final kind in PromotionKind.values) {
        expect(bodies, contains('"kind": "${kind.wireName}"'), reason: '$kind');
      }
      for (final reason in const [
        'empty_cart',
        'already_applied',
        'kind_already_applied',
        'no_matching_items',
        'minimum_not_met',
        'not_applied',
      ]) {
        expect(bodies, contains('"reason": "$reason"'), reason: reason);
      }
    });

    test(
      'T-0051-AC5: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File('${commerce.path}/fixtures/routes.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const CommerceMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(CommerceMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      },
    );

    test('T-0051-AC5: CONTRACT.md documents every route, scenario, set, code and promotion', () {
      final doc = File('${commerce.path}/CONTRACT.md').readAsStringSync();
      for (final route in CommerceMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in CommerceMockDomain.scenarioNames) {
        expect(doc, contains('`$scenario`'), reason: scenario);
      }
      for (final set in commerceFixtureSets.keys) {
        expect(doc, contains('`$set`'), reason: set);
      }
      for (final code in const [
        'unauthenticated',
        'unknown_product',
        'out_of_stock',
        'invalid_quantity',
        'invalid_body',
        'unknown_promo',
        'promo_not_applicable',
        'unknown_category',
        'invalid_parameter',
        'injected_failure',
        'empty_cart',
        'already_applied',
        'kind_already_applied',
        'no_matching_items',
        'minimum_not_met',
        'not_applied',
      ]) {
        expect(doc, contains('`$code`'), reason: code);
      }
      for (final p in promotions) {
        expect(doc, contains('`${p.code}`'), reason: p.code);
      }
    });
  });

  group('T-0051-AC5 links to the comics domain', () {
    for (final seed in [42, 7]) {
      test(
        'T-0051-AC5 seed $seed: every product id resolves on GET /v1/comics/{id}, with the same title and cover',
        () async {
          final backend = MockBackend(
            seed: seed,
            domains: [const CommerceMockDomain(), const ComicsMockDomain()],
          );
          final dio = jsonDio(backend);
          final products = <Json>[];
          for (final c in categoryDefs) {
            final page = (await getJson(
              dio,
              '/v1/store/categories/${c.id}/products?limit=100',
            )).data!;
            products.addAll((page['results']! as List).cast<Json>());
          }
          expect(products, hasLength(120 * issuesSold));
          for (final p in products) {
            final comic = (await getJson(dio, '/v1/comics/${p['id']}')).data!;
            expect(comic['id'], p['id']);
            expect(comic['title'], p['title'], reason: '$p');
            expect(comic['cover'], p['cover'], reason: '$p');
            expect(comic['issueNumber'], p['issueNumber']);
            expect(comic['seriesId'], p['seriesId']);
          }
          // Everything else the store names resolves too.
          final deals =
              (await getJson(dio, '/v1/store/deals')).data!['deals']! as List;
          final featured =
              (await getJson(dio, '/v1/store/featured')).data!['products']!
                  as List;
          final banners =
              (await getJson(dio, '/v1/store/banners')).data!['banners']!
                  as List;
          final ids = {
            for (final d in deals)
              ((d as Json)['product']! as Json)['id']! as int,
            for (final f in featured) (f as Json)['id']! as int,
            for (final b in banners)
              if (((b as Json)['target']! as Json)['type'] == 'comic')
                ((b['target']! as Json)['comicId']! as int),
          };
          expect(ids.length, greaterThan(10));
          for (final id in ids) {
            expect((await getJson(dio, '/v1/comics/$id')).statusCode, 200);
            expect(products.any((p) => p['id'] == id), isTrue, reason: '$id');
          }
        },
      );
    }

    test(
      'T-0051-AC5: every image the store serves resolves to a bundled asset',
      () async {
        final dio = jsonDio(commerceBackend());
        final images = <ApiImage>[];
        void collect(Object? value) {
          if (value is Map) {
            if (value.keys.toSet().containsAll(['path', 'variant'])) {
              images.add(_image(value));
            } else {
              value.values.forEach(collect);
            }
          } else if (value is List) {
            value.forEach(collect);
          }
        }

        for (final path in const [
          '/v1/store/banners',
          '/v1/store/deals',
          '/v1/store/categories',
          '/v1/store/featured',
          '/v1/store/categories/heroes/products?limit=100',
        ]) {
          collect((await getJson(dio, path)).data);
        }
        final line = await putQuantity(dio, 500060, 1);
        collect(line.data);
        expect(images.length, greaterThan(80));
        const resolver = BundledImageResolver();
        final seen = <String>{};
        for (final image in images) {
          for (final path in resolver.locate(image).allDensityPaths) {
            seen.add(path);
            expect(
              File('${media.path}/$path').existsSync(),
              isTrue,
              reason: '${image.path} -> $path',
            );
          }
        }
        expect(seen.length, greaterThan(24));
      },
    );

    test('T-0051-AC5: the resolver rejects an image outside the set (negative control)', () {
      const resolver = BundledImageResolver();
      expect(
        () => resolver.locate(
          ApiImage(path: 'mock-asset://characters/$coverImageCount'),
        ),
        throwsA(isA<UnresolvedImageException>()),
      );
    });

    test('T-0051-AC5: commerce.empty serves no products while the comics domain still serves its comics', () async {
      final backend = MockBackend(
        domains: [const CommerceMockDomain(), const ComicsMockDomain()],
      )..useScenario('commerce.empty');
      final dio = jsonDio(backend);
      expect(
        (await getJson(dio, '/v1/store/featured')).data!['products']! as List,
        isEmpty,
      );
      expect((await getJson(dio, '/v1/comics/500060')).statusCode, 200);
    });
  });
}
