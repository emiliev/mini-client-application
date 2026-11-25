import 'package:dio/dio.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

MockBackend _backend({List<FailureRule> failures = const []}) => MockBackend(
  domains: [const CharactersMockDomain()],
  failures: failures,
);

Dio _dio(MockBackend backend, {Monitoring? monitoring}) => createApiDio(
  adapter: backend.adapter,
  retryDelay: Duration.zero,
  monitoring: monitoring == null ? null : () => monitoring,
);

ApiFailure _failureOf(Result<Object?, ApiFailure> r) =>
    r.fold((_) => fail('expected a failure'), (f) => f);

void main() {
  group('T-0023-AC1 failures through the mocked backend', () {
    Future<ApiFailure> run(FailureKind kind, {String method = 'GET'}) async {
      final backend = _backend(
        failures: [FailureRule(method, '/v1/characters', kind)],
      );
      final dio = _dio(backend);
      final result = await apiCall<Object?>(
        () => dio.request<Object?>(
          '/v1/characters',
          options: Options(method: method),
        ),
      );
      return _failureOf(result);
    }

    test('T-0023-AC1: timeout', () async {
      expect(await run(const FailureKind.timeout()), isA<ApiTimeout>());
    });
    test('T-0023-AC1: offline', () async {
      expect(await run(const FailureKind.offline()), isA<ApiOffline>());
    });
    test('T-0023-AC1: 401', () async {
      expect(
        await run(const FailureKind.unauthorized()),
        isA<ApiUnauthorized>(),
      );
    });
    test('T-0023-AC1: 404', () async {
      expect(await run(const FailureKind.notFound()), isA<ApiNotFound>());
    });
    test('T-0023-AC1: 500', () async {
      expect(
        await run(const FailureKind.http(500)),
        isA<ApiServer>().having((f) => f.status, 'status', 500),
      );
    });
    test('T-0023-AC1: other 4xx is a client error with its status', () async {
      expect(
        await run(const FailureKind.http(403)),
        isA<ApiClientError>().having((f) => f.status, 'status', 403),
      );
    });
    test('T-0023-AC1: malformed body', () async {
      expect(await run(const FailureKind.malformed()), isA<ApiMalformed>());
    });
  });

  group('T-0023-AC2 retry', () {
    test('T-0023-AC2: GET 503 with retry 2 makes 3 attempts', () async {
      final backend = _backend(
        failures: [
          const FailureRule('GET', '/v1/characters', FailureKind.http(503)),
        ],
      );
      final dio = _dio(backend);
      final result = await apiCall<Object?>(
        () => dio.get<Object?>('/v1/characters'),
      );
      expect(_failureOf(result), isA<ApiServer>());
      expect(backend.recentTraffic, hasLength(3));
    });

    test('T-0023-AC2: GET that recovers on the 3rd attempt succeeds', () async {
      final backend = _backend(
        failures: [
          const FailureRule(
            'GET',
            '/v1/characters',
            FailureKind.http(503),
            FailureTrigger.times(2),
          ),
        ],
      );
      final response = await _dio(backend).get<Object?>('/v1/characters');
      expect(response.statusCode, 200);
      expect(backend.recentTraffic, hasLength(3));
    });

    test('T-0023-AC2: a POST is never retried', () async {
      final backend = _backend(
        failures: [
          const FailureRule('POST', '/v1/characters', FailureKind.http(503)),
        ],
      );
      final dio = _dio(backend);
      final result = await apiCall<Object?>(
        () => dio.post<Object?>('/v1/characters', data: {'name': 'x'}),
      );
      expect(_failureOf(result), isA<ApiServer>());
      expect(backend.recentTraffic, hasLength(1));
    });

    test('T-0023-AC2: a 404 GET is not retried', () async {
      final backend = _backend(
        failures: [
          const FailureRule('GET', '/v1/characters', FailureKind.notFound()),
        ],
      );
      final dio = _dio(backend);
      await apiCall<Object?>(() => dio.get<Object?>('/v1/characters'));
      expect(backend.recentTraffic, hasLength(1));
    });

    group('T-0023-AC2 request bodies and cancellation', () {
      MockBackend always503() => _backend(
        failures: [
          const FailureRule('PUT', '/v1/characters', FailureKind.http(503)),
        ],
      );

      test(
        'T-0023-AC2: a PUT with FormData is retried with a fresh copy',
        () async {
          final backend = always503();
          final dio = _dio(backend);
          final form = FormData.fromMap({
            'name': 'x',
            'file': MultipartFile.fromString('abc', filename: 'a.txt'),
          });
          final result = await apiCall<Object?>(
            () => dio.put<Object?>('/v1/characters', data: form),
          );
          // The caller sees the real failure, not a "finalized" StateError.
          expect(
            _failureOf(result),
            isA<ApiServer>().having((f) => f.status, 'status', 503),
          );
          expect(backend.recentTraffic, hasLength(3));
        },
      );

      test('T-0023-AC2: a PUT with a stream body is not retried', () async {
        final backend = always503();
        final dio = _dio(backend);
        final result = await apiCall<Object?>(
          () => dio.put<Object?>(
            '/v1/characters',
            data: Stream.fromIterable([
              [1, 2, 3],
            ]),
            options: Options(headers: {Headers.contentLengthHeader: 3}),
          ),
        );
        expect(
          _failureOf(result),
          isA<ApiServer>().having((f) => f.status, 'status', 503),
        );
        expect(backend.recentTraffic, hasLength(1));
      });

      test('T-0023-AC2: a receive timeout is not retried', () async {
        final backend = _backend(
          failures: [
            const FailureRule(
              'GET',
              '/v1/characters',
              FailureKind.slow(Duration(seconds: 5)),
            ),
          ],
        );
        final dio = _dio(backend);
        final result = await apiCall<Object?>(
          () => dio.get<Object?>(
            '/v1/characters',
            options: Options(receiveTimeout: const Duration(milliseconds: 20)),
          ),
        );
        expect(_failureOf(result), isA<ApiTimeout>());
        expect(backend.recentTraffic, hasLength(1));
      });

      test(
        'T-0023-AC2: cancelling during the backoff stops the retries',
        () async {
          final backend = always503();
          final dio = createApiDio(
            adapter: backend.adapter,
            retryDelay: const Duration(seconds: 30),
          );
          final token = CancelToken();
          final call = apiCall<Object?>(
            () => dio.put<Object?>('/v1/characters', cancelToken: token),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          token.cancel('stop');
          final failure = _failureOf(
            await call.timeout(const Duration(seconds: 5)),
          );
          expect(failure.message, contains('cancel'));
          expect(backend.recentTraffic, hasLength(1));
        },
      );
    });

    test('T-0023-AC2: each attempt is logged to monitoring once', () async {
      final sink = InMemorySink();
      final backend = _backend(
        failures: [
          const FailureRule('GET', '/v1/characters', FailureKind.http(503)),
        ],
      );
      final dio = _dio(backend, monitoring: Monitoring([sink]));
      await apiCall<Object?>(() => dio.get<Object?>('/v1/characters'));
      expect(sink.entries.whereType<LogEntry>(), hasLength(3));
    });
  });

  group('T-0023-AC4 DI', () {
    const config =
        '{"env":"dev","backend":{"seed":1,"latencyMs":0,"scenario":"happy"},'
        '"apiBaseUrl":"https://api.test/","build":"1"}';
    setUp(resetDIContainer);

    test('T-0023-AC4: an explicit baseUrl overrides the config', () async {
      await initializeDIContainer([
        ApiClientDIInitializer(
          adapter: _backend().adapter,
          baseUrl: 'https://override.test/',
          retryDelay: Duration.zero,
        ),
      ]);
      expect(diContainer<Dio>().options.baseUrl, 'https://override.test/');
    });

    test('T-0023-AC4: a missing Monitoring fails the request loudly', () async {
      await initializeDIContainer([
        ApiClientDIInitializer(
          adapter: _backend().adapter,
          baseUrl: 'https://x.test/',
        ),
      ]);
      await expectLater(
        diContainer<Dio>().get<Object?>('/v1/characters'),
        throwsA(anything),
      );
    });

    test(
      'T-0023-AC4: one shared Dio on the mocked backend returns page 1',
      () async {
        final backend = _backend();
        await initializeDIContainer([
          ConfigDIInitializer(() async => config),
          MonitoringDIInitializer(sinks: [InMemorySink()]),
          ApiClientDIInitializer(adapter: backend.adapter),
        ]);
        final dio = diContainer<Dio>();
        expect(dio.options.baseUrl, 'https://api.test/');
        expect(identical(dio, diContainer<Dio>()), isTrue);
        expect(dio.httpClientAdapter, same(backend.adapter));

        final response = await dio.get<Map<String, Object?>>('/v1/characters');
        final page = response.data!;
        expect(page['offset'], 0);
        expect(page['total'], 1500);
        expect(page['results']! as List, isNotEmpty);
      },
    );
  });

  group('T-0034-AC4 base URL and relative paths', () {
    test('T-0034-AC4: a relative path lands under the base URL', () async {
      final backend = _backend();
      final dio = _dio(backend);

      await dio.get<Object?>('v1/characters');

      expect(
        [for (final t in backend.recentTraffic) t.path],
        ['/v1/characters'],
      );
    });

    test('T-0034-AC4: a base URL without a trailing slash is normalised, '
        'in code that does not depend on asserts', () async {
      final backend = _backend();
      final dio = createApiDio(
        adapter: backend.adapter,
        baseUrl: 'https://api.test',
      );
      expect(dio.options.baseUrl, 'https://api.test/');

      await dio.get<Object?>('v1/characters');
      expect(backend.recentTraffic.single.path, '/v1/characters');
    });

    test(
      'T-0034-AC4: ApiClientDIInitializer normalises an explicit baseUrl',
      () async {
        await resetDIContainer();
        await initializeDIContainer([
          ApiClientDIInitializer(
            adapter: _backend().adapter,
            baseUrl: 'https://x.test',
          ),
        ]);
        expect(diContainer<Dio>().options.baseUrl, 'https://x.test/');
      },
    );

    test('T-0034-AC4: control: without the slash dio fuses host and path', () {
      // Dio joins baseUrl + path as strings (F-0031 B2); this is what the
      // assertion above prevents.
      final uri = RequestOptions(
        path: 'v1/characters',
        baseUrl: 'https://api.test',
      ).uri;
      expect(uri.host, 'api.testv1');
    });
  });
}
