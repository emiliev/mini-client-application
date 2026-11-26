import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'support.dart';

MockBackend _backend(String set) =>
    MockBackend(domains: [libraryFixtureSets[set]!()]);

Future<Response<Map<String, Object?>>> _get(Dio dio, String path) =>
    call<Map<String, Object?>>(dio, 'GET', path, headers: bearer(reader));

List<Call> _calls() => everyRoute('l-1');

void main() {
  test('T-0047-AC4 the fixture sets are default, empty, server_error', () {
    expect(libraryFixtureSets.keys, [
      'library.default',
      'library.empty',
      'library.server_error',
    ]);
    expect(libraryFixtureSets['library.default']!(), isA<LibraryMockDomain>());
    expect(libraryFixtureSets['library.empty']!(), isA<EmptyLibraryDomain>());
    expect(
      libraryFixtureSets['library.server_error']!(),
      isA<FailingLibraryDomain>(),
    );
    expect(libraryRouteManifest, LibraryMockDomain.routeManifest);
  });

  test('T-0047-AC4 library.default seeds lists for both users', () async {
    final dio = jsonDio(_backend('library.default'));
    expect(
      (await _get(dio, '/v1/me/lists')).data!['lists']! as List,
      hasLength(3),
    );
    expect(const LibraryMockDomain().scenarios.keys, [
      'library.empty',
      'library.server_error',
    ]);
  });

  test(
    'T-0047-AC4 library.empty has no lists, but auth and writes work',
    () async {
      final backend = _backend('library.empty');
      final dio = jsonDio(backend);
      expect((await _get(dio, '/v1/me/lists')).data, {'lists': <Object?>[]});
      expect((await _get(dio, '/v1/me/lists/l-1')).statusCode, 404);
      final noAuth = await call<Map<String, Object?>>(
        dio,
        'GET',
        '/v1/me/lists',
      );
      expect(noAuth.statusCode, 401);
      final bad = await call<Map<String, Object?>>(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': '', 'visibility': 'private', 'comicIds': <int>[]},
        headers: bearer(reader),
      );
      expect(bad.statusCode, 400);
      final created = await call<Map<String, Object?>>(
        dio,
        'POST',
        '/v1/me/lists',
        body: {
          'name': 'First',
          'visibility': 'private',
          'comicIds': comicIds(2),
        },
        headers: bearer(reader),
      );
      expect(created.statusCode, 201);
      expect(created.data!['id'], 'l-1');
      expect(
        (await _get(dio, '/v1/me/lists')).data!['lists']! as List,
        hasLength(1),
      );
      expect(const EmptyLibraryDomain().scenarios, isEmpty);
    },
  );

  test('T-0047-AC4 library.server_error answers 500 on every route', () async {
    final dio = jsonDio(_backend('library.server_error'));
    for (final (method, path, body) in _calls()) {
      final response = await call<Map<String, Object?>>(
        dio,
        method,
        path,
        body: body,
        headers: bearer(reader),
      );
      expect(response.statusCode, 500, reason: '$method $path');
      expect(response.data!['error'], containsPair('code', 'injected_failure'));
    }
    expect(const FailingLibraryDomain().scenarios, isEmpty);
  });

  test(
    'T-0047-AC4 the server_error set and scenario answer the same body',
    () async {
      final set = jsonDio(_backend('library.server_error'));
      for (final (method, path, body) in _calls()) {
        final scenario = MockBackend(domains: [const LibraryMockDomain()])
          ..useScenario('library.server_error');
        final a = await call<Map<String, Object?>>(
          jsonDio(scenario),
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        final b = await call<Map<String, Object?>>(
          set,
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        expect(a.statusCode, 500, reason: '$method $path');
        expect(b.statusCode, a.statusCode, reason: '$method $path');
        expect(b.data, a.data, reason: '$method $path');
      }
    },
  );

  test(
    'T-0047-AC4 the empty set and scenario answer the same bodies',
    () async {
      final set = _backend('library.empty');
      final scenario = MockBackend(domains: [const LibraryMockDomain()])
        ..useScenario('library.empty');
      final a = jsonDio(scenario);
      final b = jsonDio(set);
      for (final (method, path, body) in [
        ..._calls(),
        ('GET', '/v1/me/lists/l-4', null),
        ('POST', '/v1/me/lists', {'name': 'x'}),
      ]) {
        final x = await call<Object?>(
          a,
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        final y = await call<Object?>(
          b,
          method,
          path,
          body: body,
          headers: bearer(reader),
        );
        expect(y.statusCode, x.statusCode, reason: '$method $path');
        expect(y.data, x.data, reason: '$method $path');
      }
    },
  );

  test('T-0047-AC4 the empty scenario is empty even after the default '
      'set was used', () async {
    final backend = MockBackend(domains: [const LibraryMockDomain()]);
    final dio = jsonDio(backend);
    expect(
      (await _get(dio, '/v1/me/lists')).data!['lists']! as List,
      hasLength(3),
    );
    backend.useScenario('library.empty');
    expect((await _get(dio, '/v1/me/lists')).data, {'lists': <Object?>[]});
  });
}
