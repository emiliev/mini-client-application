import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Dio _dio(String set) =>
    MockBackend(domains: [discoveryFixtureSets[set]!()]).createDio();

Future<Response<Map<String, Object?>>> _res(Dio dio, String path) =>
    dio.get<Map<String, Object?>>(
      path,
      options: Options(validateStatus: (_) => true),
    );

Future<Map<String, Object?>> _get(Dio dio, String path) async =>
    (await _res(dio, path)).data!;

const _endpoints = ['/v1/search?q=spi', '/v1/search/suggestions?q=spi'];

void main() {
  test('T-0043-AC4 the fixture sets are default, empty, server_error', () {
    expect(discoveryFixtureSets.keys, [
      'discovery.default',
      'discovery.empty',
      'discovery.server_error',
    ]);
    expect(
      discoveryFixtureSets['discovery.default']!(),
      isA<DiscoveryMockDomain>(),
    );
    expect(
      discoveryFixtureSets['discovery.empty']!(),
      isA<EmptyDiscoveryDomain>(),
    );
    expect(
      discoveryFixtureSets['discovery.server_error']!(),
      isA<FailingDiscoveryDomain>(),
    );
    expect(discoveryRouteManifest, DiscoveryMockDomain.routeManifest);
  });

  test('T-0043-AC4 discovery.default serves both endpoints', () async {
    final dio = _dio('discovery.default');
    final search = await _get(dio, '/v1/search?q=spi');
    expect(search['groups']! as List, hasLength(2));
    final suggestions = await _get(dio, '/v1/search/suggestions?q=spi');
    expect(suggestions['suggestions'], hasLength(5));
  });

  test('T-0043-AC4 discovery.empty is well formed on both endpoints', () async {
    final dio = _dio('discovery.empty');
    expect(await _get(dio, '/v1/search?q=spi'), {
      'query': 'spi',
      'groups': [
        {'type': 'character', 'total': 0, 'results': <Object?>[]},
        {'type': 'comic', 'total': 0, 'results': <Object?>[]},
      ],
    });
    expect(await _get(dio, '/v1/search?q=spi&types=comic'), {
      'query': 'spi',
      'groups': [
        {'type': 'comic', 'total': 0, 'results': <Object?>[]},
      ],
    });
    expect(await _get(dio, '/v1/search/suggestions?q=spi'), {
      'query': 'spi',
      'suggestions': <Object?>[],
    });
    expect(const EmptyDiscoveryDomain().scenarios, isEmpty);
  });

  test(
    'T-0043-AC4 discovery.empty still validates like the real handler',
    () async {
      final dio = _dio('discovery.empty');
      for (final (path, code, parameter) in [
        ('/v1/search?q=s', 'query_too_short', 'q'),
        ('/v1/search?q=spi&types=film', 'invalid_parameter', 'types'),
        ('/v1/search?q=spi&limit=0', 'invalid_parameter', 'limit'),
        ('/v1/search/suggestions?q=s', 'query_too_short', 'q'),
      ]) {
        final response = await _res(dio, path);
        expect(response.statusCode, 400, reason: path);
        expect(
          response.data!['error'],
          containsPair('code', code),
          reason: path,
        );
        expect(
          response.data!['error'],
          containsPair('parameter', parameter),
          reason: path,
        );
      }
    },
  );

  test(
    'T-0043-AC4 discovery.server_error answers 500 on every endpoint',
    () async {
      final dio = _dio('discovery.server_error');
      for (final path in _endpoints) {
        final response = await _res(dio, path);
        expect(response.statusCode, 500, reason: path);
        expect(
          response.data!['error'],
          containsPair('code', 'injected_failure'),
        );
      }
      expect(const FailingDiscoveryDomain().scenarios, isEmpty);
    },
  );

  test(
    'T-0043-AC4 the server_error set and scenario answer the same body',
    () async {
      final scenario = MockBackend(domains: [const DiscoveryMockDomain()])
        ..useScenario('discovery.server_error');
      final set = _dio('discovery.server_error');
      for (final path in _endpoints) {
        final a = await _res(scenario.createDio(), path);
        final b = await _res(set, path);
        expect(a.statusCode, 500, reason: path);
        expect(b.statusCode, a.statusCode, reason: path);
        expect(b.data, a.data, reason: path);
        expect((b.data!['error']! as Map)['code'], 'injected_failure');
      }
    },
  );

  test(
    'T-0043-AC4 the empty set and scenario answer the same bodies',
    () async {
      final scenario = MockBackend(domains: [const DiscoveryMockDomain()])
        ..useScenario('discovery.empty');
      final set = _dio('discovery.empty');
      for (final path in [
        ..._endpoints,
        '/v1/search?q=spi&types=comic&limit=3',
        '/v1/search?q=s',
        '/v1/search?q=spi&types=x',
      ]) {
        final a = await _res(scenario.createDio(), path);
        final b = await _res(set, path);
        expect(b.statusCode, a.statusCode, reason: path);
        expect(b.data, a.data, reason: path);
      }
    },
  );

  test('T-0043-AC4 the default domain declares exactly the two scenarios', () {
    expect(const DiscoveryMockDomain().scenarios.keys, [
      'discovery.empty',
      'discovery.server_error',
    ]);
  });
}
