import 'package:dio/dio.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
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
  monitoring: monitoring,
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
    setUp(resetDIContainer);

    test(
      'T-0023-AC4: one shared Dio on the mocked backend returns page 1',
      () async {
        final backend = _backend();
        await initializeDIContainer([
          MonitoringDIInitializer(sinks: [InMemorySink()]),
          ApiClientDIInitializer(backend: backend),
        ]);
        final dio = diContainer<Dio>();
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
}
