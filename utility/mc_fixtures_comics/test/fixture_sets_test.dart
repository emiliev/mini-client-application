import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Dio _dio(String set) =>
    MockBackend(domains: [comicsFixtureSets[set]!()]).createDio();

Future<Response<Map<String, Object?>>> _res(Dio dio, String path) =>
    dio.get<Map<String, Object?>>(
      path,
      options: Options(validateStatus: (_) => true),
    );

Future<Map<String, Object?>> _get(Dio dio, String path) async =>
    (await _res(dio, path)).data!;

List<String> _titles(Map<String, Object?> page) => [
  for (final c in (page['results']! as List).cast<Map<String, Object?>>())
    c['title']! as String,
];

const _endpoints = ['/v1/comics', '/v1/comics/500000', '/v1/series/400000'];

void main() {
  test(
    'T-0038-AC2 the fixture sets are default, paged_45, empty, server_error',
    () {
      expect(comicsFixtureSets.keys, [
        'comics.default',
        'comics.paged_45',
        'comics.empty',
        'comics.server_error',
      ]);
      expect(comicsFixtureSets['comics.default']!(), isA<ComicsMockDomain>());
      expect(
        comicsFixtureSets['comics.server_error']!(),
        isA<FailingComicsDomain>(),
      );
      expect(comicsRouteManifest, ComicsMockDomain.routeManifest);
    },
  );

  test('T-0038-AC2 comics.default serves all three endpoints', () async {
    final dio = _dio('comics.default');
    expect((await _get(dio, '/v1/comics'))['total'], 2400);
    expect((await _get(dio, '/v1/comics/500000'))['id'], 500000);
    expect((await _get(dio, '/v1/series/400000'))['id'], 400000);
  });

  test('T-0038-AC2 comics.empty is well formed on every endpoint', () async {
    final dio = _dio('comics.empty');
    expect(await _get(dio, '/v1/comics'), {
      'offset': 0,
      'limit': 20,
      'total': 0,
      'count': 0,
      'results': <Object?>[],
    });
    for (final path in _endpoints.skip(1)) {
      final response = await _res(dio, path);
      expect(response.statusCode, 404, reason: path);
    }
    expect(const SyntheticComicsDomain(0).scenarios, isEmpty);
  });

  test(
    'T-0038-AC2 comics.server_error answers 500 on every endpoint',
    () async {
      final dio = _dio('comics.server_error');
      for (final path in _endpoints) {
        final response = await _res(dio, path);
        expect(response.statusCode, 500, reason: path);
        expect(
          response.data!['error'],
          containsPair('code', 'injected_failure'),
        );
      }
      expect(const FailingComicsDomain().scenarios, isEmpty);
    },
  );

  test('T-0038-AC2 comics.paged_45 pages 45 issues as 30 then 15', () async {
    final dio = _dio('comics.paged_45');
    final first = await _get(dio, '/v1/comics?offset=0&limit=30');
    final second = await _get(dio, '/v1/comics?offset=30&limit=30');

    expect(first['total'], 45);
    expect(_titles(first), [
      for (var i = 1; i <= 30; i++) 'Issue ${i.toString().padLeft(2, '0')}',
    ]);
    expect(second['count'], 15);
    expect(_titles(second).last, 'Issue 45');
  });

  test('T-0038-AC2 a synthetic issue has art, a detail and a series', () async {
    final dio = _dio('comics.paged_45');
    final page = await _get(dio, '/v1/comics?offset=24&limit=1');
    final comic = (page['results']! as List).single as Map<String, Object?>;
    final detail = await _get(dio, '/v1/comics/${comic['id']}');
    final series = await _get(dio, '/v1/series/400000');

    expect(comic['title'], 'Issue 25');
    expect(comic['cover'], {
      'path': 'mock-asset://characters/000',
      'variant': 'portrait_large',
    });
    expect(detail['title'], 'Issue 25');
    expect(detail['characterIds'], isEmpty);
    expect(series['comicCount'], 45);
    expect(series['title'], 'Synthetic Series');
    expect((await _res(dio, '/v1/comics/1')).statusCode, 404);
    expect(
      (await _get(dio, '/v1/comics?limit=0'))['error'],
      containsPair('code', 'invalid_parameter'),
    );
  });

  test(
    'T-0038-AC2 a synthetic catalogue past 99 still pages in title order',
    () async {
      final cast = ComicUniverse.synthetic(150).byTitle;
      final titles = [for (final c in cast) c.title];
      expect(titles.first, 'Issue 001');
      expect(titles.last, 'Issue 150');
      expect(titles, [...titles]..sort());

      final dio = MockBackend(
        domains: [const SyntheticComicsDomain(150)],
      ).createDio();
      final page = await _get(dio, '/v1/comics?offset=95&limit=10');
      expect(_titles(page), [
        for (var i = 96; i <= 105; i++) 'Issue ${'$i'.padLeft(3, '0')}',
      ]);
    },
  );

  test(
    'T-0038-AC2 the server_error set and scenario answer the same body',
    () async {
      final scenario = MockBackend(domains: [const ComicsMockDomain()])
        ..useScenario('comics.server_error');
      final set = _dio('comics.server_error');
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
}
