import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// A tiny domain: the engine ships no data of its own (R3).
final class _EchoDomain implements MockDomain {
  @override
  String get name => 'echo';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      ..get(
        '/v1/x',
        (request, context) => MockResponse.ok({
          'seed': context.seed,
          'clock': context.clock.toIso8601String(),
          'zebra': 1,
          'alpha': 2,
        }),
      )
      ..get(
        '/v1/items/:id',
        (request, context) => MockResponse.ok({'id': context.params['id']}),
      )
      ..get(
        '/v1/items/special',
        (request, context) => const MockResponse.ok({'id': 'literal'}),
      )
      ..post(
        '/v1/echo',
        (request, context) => MockResponse.ok({'got': request.body}),
      )
      ..get(
        '/v1/boom',
        (request, context) => throw StateError('handler exploded'),
      );
  }

  @override
  Map<String, MockScenario> get scenarios => {
    'echo.down': const MockScenario(
      'echo.down',
      rules: [FailureRule('GET', '/v1/x', FailureKind.http(503))],
    ),
  };
}

MockBackend _backend({
  int seed = 42,
  LatencyProfile latency = LatencyProfile.none,
  List<FailureRule> failures = const [],
}) => MockBackend(
  seed: seed,
  latency: latency,
  failures: failures,
  domains: [_EchoDomain()],
);

Future<List<int>> _bytes(Dio dio, String path) async {
  final response = await dio.get<List<int>>(
    path,
    options: Options(responseType: ResponseType.bytes),
  );
  return response.data!;
}

void main() {
  group('T-0018-AC1 determinism', () {
    test(
      'T-0018-AC1: seed 42 gives byte-identical responses on two backends',
      () async {
        Future<List<List<int>>> run() async {
          final dio = _backend().createDio();
          return [
            await _bytes(dio, '/v1/x'),
            await _bytes(dio, '/v1/items/7'),
            await _bytes(dio, '/v1/items/special'),
          ];
        }

        expect(await run(), await run());
      },
    );

    test(
      'T-0018-AC1: JSON keys come out sorted and the clock is fixed',
      () async {
        final bytes = await _bytes(_backend().createDio(), '/v1/x');
        expect(
          utf8.decode(bytes),
          '{"alpha":2,"clock":"2026-01-01T00:00:00.000Z","seed":42,"zebra":1}',
        );
      },
    );

    test('T-0018-AC1: SplitMix64 forks are stable and independent', () {
      final a = SplitMix64(42).fork('characters').fork('7');
      final b = SplitMix64(42).fork('characters').fork('7');
      expect(
        List.generate(5, (_) => a.nextInt64()),
        List.generate(5, (_) => b.nextInt64()),
      );
      expect(
        SplitMix64(42).fork('x').nextInt64(),
        isNot(SplitMix64(42).fork('y').nextInt64()),
      );
      expect(SplitMix64(42).nextInt64(), isNot(SplitMix64(43).nextInt64()));
    });
  });

  group('T-0018-AC2 latency', () {
    test('T-0018-AC2: latency none completes without advancing time', () {
      fakeAsync((async) {
        final backend = _backend();
        var direct = false;
        backend
            .handle(
              RequestOptions(path: '/v1/x', baseUrl: 'https://h.invalid'),
              null,
            )
            .then((_) => direct = true);
        async.flushMicrotasks();
        expect(direct, isTrue, reason: 'the engine adds no timer');

        var viaDio = false;
        backend.createDio().get<Object?>('/v1/x').then((_) => viaDio = true);
        // Dio itself yields to the event loop once; that is not a delay.
        async.elapse(Duration.zero);
        expect(viaDio, isTrue);
        expect(async.elapsed, Duration.zero);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('T-0018-AC2: realistic latency waits exactly the seeded delay', () {
      fakeAsync((async) {
        final backend = _backend(latency: const LatencyProfile.realistic());
        final expected = backend.latencyForRequest(0);
        expect(
          expected,
          allOf(
            greaterThanOrEqualTo(const Duration(milliseconds: 120)),
            lessThan(const Duration(milliseconds: 200)),
          ),
        );
        var done = false;
        backend.createDio().get<Object?>('/v1/x').then((_) => done = true);
        async.elapse(expected - const Duration(microseconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(microseconds: 1));
        expect(done, isTrue);
        // The same seed gives the same delay on a fresh instance.
        expect(
          _backend(latency: const LatencyProfile.realistic())
              .latencyForRequest(0),
          expected,
        );
      });
    });
  });

  group('T-0018-AC3 failure rules', () {
    test(
      'T-0018-AC3: timeout once throws connectionTimeout, then succeeds',
      () async {
        final dio = _backend(
          failures: const [
            FailureRule(
              'GET',
              '/v1/x',
              FailureKind.timeout(),
              FailureTrigger.once,
            ),
          ],
        ).createDio();

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
      },
    );

    test(
      'T-0018-AC3: offline, http, malformed, afterCalls and failNext',
      () async {
        final backend = _backend(
          failures: const [
            FailureRule(
              'GET',
              '/v1/items/:id',
              FailureKind.offline(),
              FailureTrigger.afterCalls(1),
            ),
          ],
        );
        final dio = backend.createDio();
        expect((await dio.get<Object?>('/v1/items/1')).statusCode, 200);
        await expectLater(
          dio.get<Object?>('/v1/items/2'),
          throwsA(
            isA<DioException>().having(
              (e) => e.type,
              'type',
              DioExceptionType.connectionError,
            ),
          ),
        );

        backend.failNext('GET', '/v1/x', const FailureKind.http(500));
        await expectLater(
          dio.get<Object?>('/v1/x'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              500,
            ),
          ),
        );
        expect((await dio.get<Object?>('/v1/x')).statusCode, 200);

        backend.failNext('GET', '/v1/x', const FailureKind.malformed());
        await expectLater(
          dio.get<Object?>('/v1/x'),
          throwsA(isA<DioException>()),
        );
      },
    );

    test('T-0018-AC3: seeded probability is repeatable', () async {
      Future<List<bool>> run() async {
        final dio = _backend(
          failures: const [
            FailureRule(
              'GET',
              '/v1/x',
              FailureKind.http(503),
              FailureTrigger.probability(0.5),
            ),
          ],
        ).createDio();
        final failed = <bool>[];
        for (var i = 0; i < 20; i++) {
          try {
            await dio.get<Object?>('/v1/x');
            failed.add(false);
          } on DioException {
            failed.add(true);
          }
        }
        return failed;
      }

      final first = await run();
      expect(await run(), first);
      expect(first, contains(true));
      expect(first, contains(false));
    });

    test(
      'T-0018-AC3: a scenario applies its rules and reset clears it',
      () async {
        final backend = _backend();
        final dio = backend.createDio();
        backend.useScenario('echo.down');
        await expectLater(
          dio.get<Object?>('/v1/x'),
          throwsA(isA<DioException>()),
        );
        backend.reset();
        expect((await dio.get<Object?>('/v1/x')).statusCode, 200);
        expect(() => backend.useScenario('nope'), throwsArgumentError);
      },
    );
  });

  group('T-0018-AC4 unknown routes', () {
    test(
      'T-0018-AC4: an unregistered route is 404 and names the path',
      () async {
        final response = await _backend().createDio().get<Map<String, Object?>>(
          '/v1/nope/7',
          options: Options(validateStatus: (_) => true),
        );
        expect(response.statusCode, 404);
        final error = response.data!['error']! as Map<String, Object?>;
        expect(error['message'], contains('/v1/nope/7'));
        expect(error['path'], '/v1/nope/7');
      },
    );

    test(
      'T-0018-AC4: literal routes beat parameter routes, wrong method is 404',
      () async {
        final dio = _backend().createDio();
        expect(
          (await dio.get<Map<String, Object?>>('/v1/items/special')).data,
          {'id': 'literal'},
        );
        expect((await dio.get<Map<String, Object?>>('/v1/items/9')).data, {
          'id': '9',
        });
        final wrong = await dio.delete<Object?>(
          '/v1/x',
          options: Options(validateStatus: (_) => true),
        );
        expect(wrong.statusCode, 404);
      },
    );

    test(
      'T-0018-AC4: a throwing handler is a 500, and POST bodies arrive',
      () async {
        final dio = _backend().createDio();
        final boom = await dio.get<Map<String, Object?>>(
          '/v1/boom',
          options: Options(validateStatus: (_) => true),
        );
        expect(boom.statusCode, 500);
        final echo = await dio.post<Map<String, Object?>>(
          '/v1/echo',
          data: {'a': 1},
        );
        expect(echo.data, {
          'got': {'a': 1},
        });
      },
    );
  });

  group('T-0018-AC5 traffic diagnostics', () {
    test(
      'T-0018-AC5: the stream emits method, path, status and duration',
      () async {
        final backend = _backend(
          latency: const LatencyProfile.slow(
            Duration(milliseconds: 5),
          ),
        );
        final dio = backend.createDio();
        final seen = <TrafficEntry>[];
        final sub = backend.traffic.listen(seen.add);

        await dio.get<Object?>('/v1/x', queryParameters: {'q': '1'});
        await dio.get<Object?>(
          '/v1/missing',
          options: Options(validateStatus: (_) => true),
        );
        backend.failNext('GET', '/v1/x', const FailureKind.timeout());
        await dio.get<Object?>('/v1/x').then((_) {}, onError: (_) {});
        await sub.cancel();

        expect(seen.map((e) => e.method), ['GET', 'GET', 'GET']);
        expect(seen.map((e) => e.path), ['/v1/x', '/v1/missing', '/v1/x']);
        expect(seen.map((e) => e.status), [200, 404, null]);
        expect(seen.map((e) => e.error), [null, null, 'connectionTimeout']);
        expect(
          seen.every((e) => e.duration == const Duration(milliseconds: 5)),
          isTrue,
        );
        expect(backend.recentTraffic, hasLength(3));
      },
    );

    test('T-0018-AC5: the ring buffer keeps the last N requests', () async {
      final backend = MockBackend(
        domains: [_EchoDomain()],
        trafficCapacity: 3,
      );
      final dio = backend.createDio();
      for (var i = 0; i < 5; i++) {
        await dio.get<Object?>('/v1/items/$i');
      }
      expect(backend.recentTraffic.map((e) => e.path), [
        '/v1/items/2',
        '/v1/items/3',
        '/v1/items/4',
      ]);
    });
  });
}
