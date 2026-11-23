// T-0018 Verifier black-box checks. Not part of the product: kept as evidence.
// To rerun, copy into utility/mc_fixtures_characters/test/ and add a temporary
// flutter_test target with the same deps as `characters_test` plus
// `@pub_deps//:fake_async` and data `//utility/mc_fixtures_media:asset_files`.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

int counted = 0;

final class _X implements MockDomain {
  @override
  String get name => 'x';
  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      ..get('/v1/x', (r, c) => const MockResponse.ok({'ok': true}))
      ..post('/v1/x', (r, c) => const MockResponse.ok({'posted': true}))
      ..get('/v1/y', (r, c) => const MockResponse.ok({'y': true}))
      ..get('/v1/counted', (r, c) {
        counted++;
        return const MockResponse.ok({'ok': true});
      });
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

MockBackend _chars(int seed, {LatencyProfile latency = LatencyProfile.none}) =>
    MockBackend(
      seed: seed,
      latency: latency,
      domains: [const CharactersMockDomain(), _X()],
    );

const _sequence = [
  '/v1/characters',
  '/v1/characters?offset=30&limit=30',
  '/v1/characters?nameStartsWith=spi&limit=50',
  '/v1/characters?orderBy=-modified&limit=40',
  '/v1/characters/100000',
  '/v1/characters/101499',
  '/v1/characters/1',
  '/v1/characters?limit=0',
  '/v1/unknown',
];

Future<List<int>> _bytes(Dio dio, String path) async {
  final r = await dio.get<List<int>>(
    path,
    options: Options(
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
    ),
  );
  return r.data!;
}

Future<List<String>> _run(MockBackend b) async {
  final dio = b.createDio();
  return [for (final p in _sequence) base64Encode(await _bytes(dio, p))];
}

Future<Map<String, Object?>> _get(Dio dio, String path) async =>
    (await dio.get<Map<String, Object?>>(
      path,
      options: Options(validateStatus: (_) => true),
    )).data!;

List<Map<String, Object?>> _results(Map<String, Object?> page) =>
    (page['results']! as List).cast<Map<String, Object?>>();

// Independent model of the name catalogue (copied word lists would make this a
// tautology; instead derive only from the public formula documented in
// vocabulary.dart: 40 x 40 words, alias = i % 40, title = i ~/ 40).
const _spAliases = ['Spindle', 'Spirit', 'Spiral', 'Spire'];

void main() {
  group('VERIFIER T-0018-AC1', () {
    test(
      'VERIFIER T-0018-AC1: same seed, two instances, byte-identical',
      () async {
        final a = await _run(_chars(42));
        final b = await _run(_chars(42));
        expect(a, b);
        // Also under realistic latency (timers, seeded jitter).
        final c = await _run(
          _chars(
            42,
            latency: const LatencyProfile.realistic(
              base: Duration(milliseconds: 1),
              jitter: Duration(milliseconds: 2),
            ),
          ),
        );
        expect(c, a);
      },
    );

    test('VERIFIER T-0018-AC1: a different seed differs', () async {
      final a = await _run(_chars(42));
      final b = await _run(_chars(43));
      expect(a, isNot(b));
      // The data-bearing responses differ, error bodies do not.
      expect(a[0], isNot(b[0]));
      expect(a[4], isNot(b[4]));
      expect(a[6], b[6]);
      expect(a[8], b[8]);
    });

    test('VERIFIER T-0018-AC1: seeded latency differs across seeds but not instances', () {
      const p = LatencyProfile.realistic();
      final d42 = [
        for (var i = 0; i < 10; i++)
          _chars(42, latency: p).latencyForRequest(i),
      ];
      final d42b = [
        for (var i = 0; i < 10; i++)
          _chars(42, latency: p).latencyForRequest(i),
      ];
      final d43 = [
        for (var i = 0; i < 10; i++)
          _chars(43, latency: p).latencyForRequest(i),
      ];
      expect(d42, d42b);
      expect(d42, isNot(d43));
    });
  });

  group('VERIFIER T-0018-AC3', () {
    test('VERIFIER T-0018-AC3: timeout once fires exactly once', () async {
      final backend = MockBackend(
        domains: [_X()],
        failures: const [
          FailureRule(
            'GET',
            '/v1/x',
            FailureKind.timeout(),
            FailureTrigger.once,
          ),
        ],
      );
      final dio = backend.createDio();
      // Non-matching requests first: must not consume the rule.
      expect((await dio.get<Object?>('/v1/y')).statusCode, 200);
      expect((await dio.post<Object?>('/v1/x')).statusCode, 200);
      var timeouts = 0;
      var ok = 0;
      for (var i = 0; i < 6; i++) {
        try {
          final r = await dio.get<Object?>('/v1/x');
          expect(r.statusCode, 200);
          ok++;
        } on DioException catch (e) {
          expect(e.type, DioExceptionType.connectionTimeout);
          expect(i, 0, reason: 'only call 1 may fail');
          timeouts++;
        }
      }
      expect(timeouts, 1);
      expect(ok, 5);
      // reset() re-arms the configured rule exactly once more.
      backend.reset();
      await expectLater(
        dio.get<Object?>('/v1/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
      expect((await dio.get<Object?>('/v1/x')).statusCode, 200);
    });

    test('VERIFIER T-0018-AC3: failNext fires once', () async {
      final backend = MockBackend(domains: [_X()]);
      final dio = backend.createDio();
      backend.failNext('GET', '/v1/x', const FailureKind.timeout());
      var fails = 0;
      for (var i = 0; i < 4; i++) {
        try {
          await dio.get<Object?>('/v1/x');
        } on DioException {
          fails++;
        }
      }
      expect(fails, 1);
    });
  });

  group('VERIFIER T-0018-AC6', () {
    late Dio dio;
    setUp(() => dio = _chars(42).createDio());

    test(
      'VERIFIER T-0018-AC6: offset 0, default limit, last page, beyond',
      () async {
        final first = await _get(dio, '/v1/characters?offset=0&limit=30');
        expect(first['count'], 30);
        expect(first['offset'], 0);
        expect(first['total'], 1500);
        final noOffset = await _get(dio, '/v1/characters?limit=30');
        expect(noOffset, first);
        final dflt = await _get(dio, '/v1/characters');
        expect(dflt['limit'], 20);
        expect(dflt['count'], 20);

        final last = await _get(dio, '/v1/characters?offset=1470&limit=30');
        expect(last['count'], 30);
        final partial = await _get(dio, '/v1/characters?offset=1499&limit=30');
        expect(partial['count'], 1);
        for (final off in [1500, 1501, 5000, 999999]) {
          final beyond = await _get(dio, '/v1/characters?offset=$off&limit=30');
          expect(beyond['count'], 0, reason: 'offset $off');
          expect(beyond['total'], 1500);
          expect(beyond['offset'], off);
          expect(beyond['results'], isEmpty);
        }
      },
    );

    test('VERIFIER T-0018-AC6: page 2 equals items 30..59 of an independent ordering', () async {
      // Independent model: sorted list of all names with id tie-break.
      final all = <(String, int)>[];
      for (var off = 0; off < 1500; off += 100) {
        for (final c in _results(
          await _get(dio, '/v1/characters?offset=$off&limit=100'),
        )) {
          all.add((c['name']! as String, c['id']! as int));
        }
      }
      expect(all, hasLength(1500));
      expect({for (final e in all) e.$2}, hasLength(1500));
      final sorted = [...all]
        ..sort((a, b) {
          final n = a.$1.compareTo(b.$1);
          return n != 0 ? n : a.$2.compareTo(b.$2);
        });
      expect(all, sorted, reason: 'concatenated pages are in name order');
      final page2 = _results(
        await _get(dio, '/v1/characters?offset=30&limit=30'),
      );
      expect(
        [for (final c in page2) c['id']],
        [for (final e in all.sublist(30, 60)) e.$2],
      );
      // Repeating the request on the same and on a fresh backend is stable.
      for (var i = 0; i < 3; i++) {
        expect(
          _results(await _get(dio, '/v1/characters?offset=30&limit=30')),
          page2,
        );
      }
      expect(
        _results(
          await _get(
            _chars(42).createDio(),
            '/v1/characters?offset=30&limit=30',
          ),
        ),
        page2,
      );
      // id formula: id = 100000 + i, name = alias[i%40] + ' ' + title[i~/40].
      for (final e in all) {
        final i = e.$2 - 100000;
        expect(i, inInclusiveRange(0, 1499));
      }
    });

    test('VERIFIER T-0018-AC6: nameStartsWith is case-insensitive, counted independently', () async {
      // Sp* aliases are indices 0..3; titles 0..37 for alias < 20 (1500 = 37*40 + 20).
      const expected = 4 * 38; // 152
      final expectedIds = <int>{
        for (var i = 0; i < 1500; i++)
          if (i % 40 < 4) 100000 + i,
      };
      expect(expectedIds, hasLength(expected));
      Map<String, Object?>? reference;
      for (final q in ['spi', 'SPI', 'Spi', 'sPi', 'sPI']) {
        final ids = <int>{};
        final names = <String>[];
        for (var off = 0; off < 200; off += 100) {
          final page = await _get(
            dio,
            '/v1/characters?nameStartsWith=$q&limit=100&offset=$off',
          );
          expect(page['total'], expected, reason: q);
          for (final c in _results(page)) {
            final name = c['name']! as String;
            expect(name.toLowerCase().startsWith('spi'), isTrue, reason: name);
            expect(_spAliases.any(name.startsWith), isTrue, reason: name);
            ids.add(c['id']! as int);
            names.add(name);
          }
        }
        expect(ids, expectedIds, reason: q);
        final sortedNames = [...names]..sort();
        expect(names, sortedNames, reason: 'search keeps name order');
        final p = await _get(dio, '/v1/characters?nameStartsWith=$q&limit=5');
        reference ??= p;
        expect(p, reference, reason: 'case variants give the same page');
      }
      // Past the end of the search result set.
      final tail = await _get(
        dio,
        '/v1/characters?nameStartsWith=spi&offset=150&limit=30',
      );
      expect(tail['count'], 2);
      // Sparrow / Static do not leak in.
      final spa = await _get(
        dio,
        '/v1/characters?nameStartsWith=spa&limit=100',
      );
      expect(spa['total'], 38);
    });
  });

  group('VERIFIER T-0018-AC7', () {
    test('VERIFIER T-0018-AC7: snapshot facts match an independent derivation', () {
      Map<String, Object?> load(String n) {
        for (final base in [
          '${Platform.environment['TEST_SRCDIR']}/${Platform.environment['TEST_WORKSPACE'] ?? '_main'}/utility/mc_fixtures_characters',
          'utility/mc_fixtures_characters',
        ]) {
          final f = File('$base/test/contract/snapshots/$n.json');
          if (f.existsSync())
            return jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
        }
        throw StateError('no snapshot $n');
      }

      // ids follow 100000 + titleIndex*40 + aliasIndex. Amber = alias 6,
      // Alchemist = title 12, Artisan = 35, Bard = 36.
      final first =
          (load('list_first_page')['body']! as Map)['results'] as List;
      expect(
        [for (final c in first) (c as Map)['id']],
        [100486, 101406, 101446],
      );
      final detail = load('detail')['body']! as Map;
      expect(detail['name'], 'Spindle Warden'); // alias 0, title 0
      final spi = load('list_search_spi')['body']! as Map;
      expect(spi['total'], 152);
      final desc = (load('list_order_desc')['body']! as Map)['results'] as List;
      // Zephyr = alias 29; Weaver = title 5, Watcher = title 34.
      expect([for (final c in desc) (c as Map)['id']], [100229, 101389]);
      expect(load('list_invalid_limit')['status'], 400);
      expect(load('detail_not_found')['status'], 404);
    });

    test('VERIFIER T-0018-AC7: assets are valid PNGs at 1x/2x/3x sizes', () {
      String? dir;
      for (final base in [
        '${Platform.environment['TEST_SRCDIR']}/${Platform.environment['TEST_WORKSPACE'] ?? '_main'}/utility/mc_fixtures_media',
        'utility/mc_fixtures_media',
      ]) {
        if (Directory('$base/assets/characters').existsSync()) dir = base;
      }
      expect(dir, isNotNull);
      const resolver = BundledImageResolver();
      for (var i = 0; i < placeholderSets['characters']!; i++) {
        final b = resolver.resolve(
          ApiImage(path: 'mock-asset://characters/$i'),
        );
        final paths = b.allDensityPaths;
        for (var s = 0; s < 3; s++) {
          final bytes = File('$dir/${paths[s]}').readAsBytesSync();
          expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
          final bd = ByteData.sublistView(Uint8List.fromList(bytes));
          expect(bd.getUint32(16), 60 * (s + 1), reason: paths[s]);
          expect(bd.getUint32(20), 90 * (s + 1), reason: paths[s]);
        }
      }
    });

    testWidgets(
      'VERIFIER T-0018-AC7: an asset key from a response loads from the Flutter bundle',
      (tester) async {
        final ByteData? loaded = await tester.runAsync(() async {
          final data = await _get(
            _chars(42).createDio(),
            '/v1/characters/100000',
          );
          final image = ApiImage.fromJson((data['thumbnail']! as Map).cast());
          final key = const BundledImageResolver().resolve(image).assetKey;
          return rootBundle.load(key);
        });
        expect(loaded, isNotNull);
        expect(loaded!.lengthInBytes, greaterThan(100));
        // Negative control: a key that is not bundled must fail to load.
        final Object? missing = await tester.runAsync<Object?>(() async {
          try {
            await rootBundle.load(
              'packages/mc_fixtures_media/assets/characters/999.png',
            );
            return null;
          } on Object catch (e) {
            return e;
          }
        });
        expect(missing, isNotNull);
      },
    );
  });

  group('VERIFIER review fixes (8a93613)', () {
    test(
      'VERIFIER fix: injected rule wins and the shadowed rule is not consumed',
      () async {
        final backend = MockBackend(
          domains: [_X()],
          failures: const [FailureRule('GET', '/v1/x', FailureKind.http(500))],
        );
        final dio = backend.createDio();
        backend.failNext('GET', '/v1/x', const FailureKind.timeout());
        await expectLater(
          dio.get<Object?>('/v1/x'),
          throwsA(
            isA<DioException>().having(
              (e) => e.type,
              'type',
              DioExceptionType.connectionTimeout,
            ),
          ),
        );
        final second = await dio.get<Object?>(
          '/v1/x',
          options: Options(validateStatus: (_) => true),
        );
        expect(second.statusCode, 500);
        // A once rule shadowed by an injected one is still armed afterwards.
        final b2 = MockBackend(
          domains: [_X()],
          failures: const [
            FailureRule(
              'GET',
              '/v1/x',
              FailureKind.timeout(),
              FailureTrigger.once,
            ),
          ],
        );
        final d2 = b2.createDio();
        b2.failNext('GET', '/v1/x', const FailureKind.http(503));
        expect(
          (await d2.get<Object?>(
            '/v1/x',
            options: Options(validateStatus: (_) => true),
          )).statusCode,
          503,
        );
        await expectLater(
          d2.get<Object?>('/v1/x'),
          throwsA(
            isA<DioException>().having(
              (e) => e.type,
              'type',
              DioExceptionType.connectionTimeout,
            ),
          ),
        );
        expect((await d2.get<Object?>('/v1/x')).statusCode, 200);
      },
    );

    test('VERIFIER fix: BaseOptions connect and receive timeouts are honoured (real time)', () async {
      final backend = MockBackend(
        domains: [_X()],
        latency: const LatencyProfile.slow(Duration(milliseconds: 400)),
      );
      final dio = backend.createDio()
        ..options.connectTimeout = const Duration(milliseconds: 30);
      final sw = Stopwatch()..start();
      await expectLater(
        dio.get<Object?>('/v1/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
      expect(sw.elapsedMilliseconds, lessThan(300));
      final dio2 = backend.createDio()
        ..options.receiveTimeout = const Duration(milliseconds: 30);
      await expectLater(
        dio2.get<Object?>('/v1/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
      // Within the timeout it still succeeds.
      final dio3 = backend.createDio()
        ..options.receiveTimeout = const Duration(seconds: 2);
      expect((await dio3.get<Object?>('/v1/x')).statusCode, 200);
      expect(backend.recentTraffic.map((e) => e.error), [
        'connectionTimeout',
        'receiveTimeout',
        null,
      ]);
    });

    test(
      'VERIFIER fix: %FF in a path parameter or query is a logged 400',
      () async {
        final backend = _chars(42);
        for (final path in [
          '/v1/characters/%FF',
          '/v1/characters?nameStartsWith=%FF',
        ]) {
          final r = await backend.adapter.fetch(
            RequestOptions(path: path, baseUrl: 'https://h.invalid'),
            null,
            null,
          );
          expect(r.statusCode, 400, reason: path);
        }
        expect(backend.recentTraffic.map((e) => e.status), [400, 400]);
      },
    );

    test(
      'VERIFIER fix: strict digits for ids, offset, limit and image ids',
      () async {
        final dio = _chars(42).createDio();
        for (final q in [
          'offset=1.0',
          'offset=%2D0',
          'limit=0x1F',
          'limit=%2B30',
          'limit=99999999999999999999999',
        ]) {
          final body = await _get(dio, '/v1/characters?$q');
          expect(
            (body['error']! as Map)['code'],
            'invalid_parameter',
            reason: q,
          );
        }
        for (final id in ['1e5', '0x186A0', '-100000', '%2B100000']) {
          final body = await _get(dio, '/v1/characters/$id');
          expect(
            (body['error']! as Map)['code'],
            'character_not_found',
            reason: id,
          );
        }
        const resolver = BundledImageResolver();
        for (final p in [
          'mock-asset://characters/1e1',
          'mock-asset://characters/0x1',
          'mock-asset://characters/%2B1',
        ]) {
          expect(
            () => resolver.resolve(ApiImage(path: p)),
            throwsA(isA<UnresolvedImageException>()),
            reason: p,
          );
        }
      },
    );

    test('VERIFIER fix: a Dio CancelToken during the delay cancels and skips the handler (real time)', () async {
      counted = 0;
      final backend = MockBackend(
        domains: [_X()],
        latency: const LatencyProfile.slow(Duration(milliseconds: 300)),
      );
      final dio = backend.createDio();
      final token = CancelToken();
      final f = dio.get<Object?>('/v1/counted', cancelToken: token);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      token.cancel('verifier');
      await expectLater(
        f,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(counted, 0);
      expect(backend.recentTraffic.single.error, 'cancel');
    });

    test(
      'VERIFIER fix: characters.empty validates; router ties throw',
      () async {
        final backend = _chars(42)..useScenario('characters.empty');
        final dio = backend.createDio();
        expect(
          ((await _get(dio, '/v1/characters?limit=0'))['error']!
              as Map)['code'],
          'invalid_parameter',
        );
        expect((await _get(dio, '/v1/characters?limit=5'))['total'], 0);
        MockResponse h(MockRequest r, MockContext c) => const MockResponse(200);
        final router = MockRouter()..get('/v1/:a', h);
        expect(() => router.get('/v1/:b', h), throwsStateError);
        expect(() => router.post('/v1/:b', h), returnsNormally);
        expect(() => router.get('/v1/lit', h), returnsNormally);
      },
    );
  });
}
