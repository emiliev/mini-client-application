import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const int _comicCount = seriesCount * issuesPerSeries;

MockBackend _backend({int seed = 42}) =>
    MockBackend(seed: seed, domains: [const ComicsMockDomain()]);

/// The raw body text of a GET, whatever the status.
Future<String> _raw(Dio dio, String path) async {
  final response = await dio.get<String>(
    path,
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  return '${response.statusCode} ${response.data}';
}

Future<Map<String, Object?>> _get(Dio dio, String path) async {
  final response = await dio.get<Map<String, Object?>>(
    path,
    options: Options(validateStatus: (_) => true),
  );
  return response.data!;
}

List<Map<String, Object?>> _results(Map<String, Object?> page) =>
    (page['results']! as List).cast<Map<String, Object?>>();

void main() {
  late Dio dio;
  setUp(() => dio = _backend().createDio());

  group('T-0038-AC1 determinism', () {
    const sequence = [
      '/v1/comics',
      '/v1/comics?offset=100&limit=100&orderBy=-releaseDate',
      '/v1/comics?titleStartsWith=amb&limit=50',
      '/v1/comics?characterId=100000',
      '/v1/comics/500000',
      '/v1/comics/501234',
      '/v1/comics/1',
      '/v1/series/400000',
      '/v1/series/400119',
      '/v1/series/9',
      '/v1/comics?limit=0',
    ];

    test(
      'T-0038-AC1: seed 42 gives byte-identical responses on two backends',
      () async {
        final a = _backend().createDio();
        final b = _backend().createDio();
        var bytes = 0;
        for (final path in sequence) {
          final first = await _raw(a, path);
          expect(first, await _raw(b, path), reason: path);
          bytes += first.length;
        }
        // Not vacuous: the sequence returned real content.
        expect(bytes, greaterThan(20000));
      },
    );

    test('T-0038-AC1: another seed changes the data, not the titles', () async {
      final other = _backend(seed: 7).createDio();
      const path = '/v1/comics/500000';
      expect(await _raw(other, path), isNot(await _raw(dio, path)));
      final a = (await _get(dio, path))['title'];
      final b = (await _get(other, path))['title'];
      expect(a, b);
    });

    test('T-0038-AC1: seed 42 pins the first comic', () async {
      final first = _results(await _get(dio, '/v1/comics?limit=1')).single;
      expect(first['title'], 'Amber Chronicles #1');
    });
  });

  group('T-0038-AC2 paging', () {
    test(
      'T-0038-AC2: the order is stable, sorted and covers every comic',
      () async {
        final seen = <int>{};
        String? previous;
        for (var offset = 0; offset < _comicCount; offset += 100) {
          final page = await _get(dio, '/v1/comics?offset=$offset&limit=100');
          expect(page['total'], _comicCount);
          expect(page['count'], 100);
          for (final c in _results(page)) {
            final title = c['title']! as String;
            if (previous != null) {
              expect(title.compareTo(previous), greaterThanOrEqualTo(0));
            }
            previous = title;
            expect(
              seen.add(c['id']! as int),
              isTrue,
              reason: 'duplicate $title',
            );
          }
        }
        expect(seen, hasLength(_comicCount));
        final again = await _get(
          _backend().createDio(),
          '/v1/comics?offset=40&limit=30',
        );
        expect(again, await _get(dio, '/v1/comics?offset=40&limit=30'));
      },
    );

    test(
      'T-0038-AC2: the last page is short and past the end is empty',
      () async {
        final last = await _get(dio, '/v1/comics?offset=2390&limit=30');
        expect(last['count'], 10);
        final beyond = await _get(dio, '/v1/comics?offset=2400');
        expect(beyond['count'], 0);
        expect(beyond['total'], _comicCount);
      },
    );

    test('T-0038-AC2: every order is a total order over all comics', () async {
      for (final order in ['title', '-title', 'releaseDate', '-releaseDate']) {
        final ids = <int>[];
        for (var offset = 0; offset < _comicCount; offset += 100) {
          final page = await _get(
            dio,
            '/v1/comics?offset=$offset&limit=100&orderBy=$order',
          );
          ids.addAll([for (final c in _results(page)) c['id']! as int]);
        }
        expect(ids.toSet(), hasLength(_comicCount), reason: order);
      }
      final newest = _results(
        await _get(dio, '/v1/comics?orderBy=-releaseDate&limit=50'),
      );
      final dates = [for (final c in newest) c['releaseDate']! as String];
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
    });

    test(
      'T-0038-AC2: title order lists a series by issue number, not text',
      () async {
        final asc = await _get(
          dio,
          '/v1/comics?titleStartsWith=Amber%20Chronicles&limit=100',
        );
        expect(
          [for (final c in _results(asc)) c['issueNumber']],
          [
            for (var i = 1; i <= issuesPerSeries; i++) i,
          ],
        );
        final desc = await _get(
          dio,
          '/v1/comics?titleStartsWith=Amber%20Chronicles&limit=100'
          '&orderBy=-title',
        );
        expect(
          [for (final c in _results(desc)) c['issueNumber']],
          [
            for (var i = issuesPerSeries; i >= 1; i--) i,
          ],
        );
        // The whole listing is in (series title, issue) order.
        final all = <(String, int)>[];
        for (var offset = 0; offset < _comicCount; offset += 100) {
          final page = await _get(dio, '/v1/comics?offset=$offset&limit=100');
          for (final c in _results(page)) {
            final title = c['title']! as String;
            all.add((
              title.substring(0, title.lastIndexOf(' #')),
              c['issueNumber']! as int,
            ));
          }
        }
        final sorted = [...all]
          ..sort((a, b) {
            final bySeries = a.$1.compareTo(b.$1);
            return bySeries != 0 ? bySeries : a.$2.compareTo(b.$2);
          });
        expect(all, sorted);
      },
    );

    test(
      'T-0038-AC2: equal sort keys break on id, ascending, both ways',
      () async {
        // Several comics share a release date, so the tie-break has work to do.
        final byDate = <String, List<int>>{};
        for (final c in ComicUniverse(42).byTitle) {
          (byDate[c.releaseDate.toIso8601String()] ??= []).add(c.id);
        }
        final tied = byDate.values.where((ids) => ids.length > 1).toList();
        expect(tied, isNotEmpty, reason: 'the data must contain ties');

        for (final order in ['releaseDate', '-releaseDate']) {
          final ids = <int>[];
          final dates = <String>[];
          for (var offset = 0; offset < _comicCount; offset += 100) {
            final page = await _get(
              dio,
              '/v1/comics?offset=$offset&limit=100&orderBy=$order',
            );
            for (final c in _results(page)) {
              ids.add(c['id']! as int);
              dates.add(c['releaseDate']! as String);
            }
          }
          var checked = 0;
          for (var i = 1; i < ids.length; i++) {
            if (dates[i] == dates[i - 1]) {
              checked++;
              expect(ids[i], greaterThan(ids[i - 1]), reason: '$order at $i');
            }
          }
          expect(checked, greaterThan(0), reason: order);
        }
      },
    );

    test('T-0038-AC2: titleStartsWith is a case-insensitive prefix', () async {
      final page = await _get(dio, '/v1/comics?titleStartsWith=SPI&limit=100');
      expect(page['total'], 400);
      for (final c in _results(page)) {
        expect((c['title']! as String).toLowerCase(), startsWith('spi'));
      }
      expect(
        (await _get(dio, '/v1/comics?titleStartsWith=zzz'))['total'],
        0,
      );
      expect(
        (await _get(dio, '/v1/comics?titleStartsWith='))['total'],
        _comicCount,
      );
    });

    test(
      'T-0038-AC2: characterId returns exactly the comics featuring it',
      () async {
        final page = await _get(dio, '/v1/comics?characterId=100000&limit=100');
        final ids = [for (final c in _results(page)) c['id']! as int];
        expect(page['total'], 6);
        for (final id in ids) {
          final detail = await _get(dio, '/v1/comics/$id');
          expect(detail['characterIds'], contains(100000));
        }
        // The reverse: nothing else features it.
        var featuring = 0;
        for (final c in ComicUniverse(42).byTitle) {
          if (c.characterIds.contains(100000)) {
            featuring++;
          }
        }
        expect(featuring, 6);
        expect(
          (await _get(dio, '/v1/comics?characterId=1'))['total'],
          0,
          reason: 'an unknown character matches nothing',
        );
      },
    );

    test(
      'T-0038-AC2: a bad query value is a 400 naming the parameter',
      () async {
        for (final (query, parameter) in const [
          ('limit=0', 'limit'),
          ('limit=101', 'limit'),
          ('offset=-1', 'offset'),
          ('offset=0x10', 'offset'),
          ('orderBy=price', 'orderBy'),
          ('characterId=x', 'characterId'),
        ]) {
          final body = await _get(dio, '/v1/comics?$query');
          expect(
            body['error'],
            containsPair('parameter', parameter),
            reason: query,
          );
          expect(
            (body['error']! as Map)['code'],
            'invalid_parameter',
            reason: query,
          );
        }
      },
    );
  });

  group('T-0038-AC2 details', () {
    test(
      'T-0038-AC2: a comic detail has everything the screen needs',
      () async {
        final comic = await _get(dio, '/v1/comics/500000');
        expect(comic.keys.toSet(), {
          'id',
          'title',
          'issueNumber',
          'seriesId',
          'cover',
          'releaseDate',
          'description',
          'series',
          'creators',
          'characterIds',
          'price',
          'pageCount',
          'variants',
        });
        expect(comic['series'], {'id': 400000, 'title': 'Spindle Chronicles'});
        expect((comic['creators']! as List).length, greaterThanOrEqualTo(2));
        expect(comic['price'], containsPair('currency', 'USD'));
        expect(comic['releaseDate'], matches(r'^\d{4}-\d{2}-\d{2}$'));
      },
    );

    test(
      'T-0038-AC2: GET /v1/comics/{unknown} is a 404 naming the id',
      () async {
        for (final raw in ['1', '999999999', 'abc', '0x10']) {
          final body = await _get(dio, '/v1/comics/$raw');
          final error = body['error']! as Map<String, Object?>;
          expect(error['code'], 'comic_not_found', reason: raw);
          expect(error['id'], raw);
          expect(error['message'], contains(raw));
        }
        final response = await dio.get<Object?>(
          '/v1/comics/1',
          options: Options(validateStatus: (_) => true),
        );
        expect(response.statusCode, 404);
      },
    );

    test(
      'T-0038-AC2: a series detail lists its comics in issue order',
      () async {
        final series = await _get(dio, '/v1/series/400041');
        expect(series['title'], 'Cinder Vanguard');
        expect(series['comicCount'], issuesPerSeries);
        final ids = (series['comicIds']! as List).cast<int>();
        for (var i = 0; i < ids.length; i++) {
          final comic = await _get(dio, '/v1/comics/${ids[i]}');
          expect(comic['seriesId'], 400041);
          expect(comic['issueNumber'], i + 1);
        }
        expect(
          series['startYear'],
          lessThanOrEqualTo(series['endYear']! as int),
        );
      },
    );

    test(
      'T-0038-AC2: GET /v1/series/{unknown} is a 404 naming the id',
      () async {
        final body = await _get(dio, '/v1/series/1');
        expect(body['error'], containsPair('code', 'series_not_found'));
        expect(body['error'], containsPair('id', '1'));
      },
    );

    test('T-0038-AC2: universe facts hold', () {
      final universe = ComicUniverse(42);
      expect(universe.byTitle, hasLength(_comicCount));
      expect(universe.allSeries, hasLength(seriesCount));
      expect(creatorCount, 60);
      for (final c in universe.byTitle) {
        expect(c.pageCount, inInclusiveRange(24, 56));
        expect(c.releaseDate.isBefore(defaultMockClock), isTrue);
      }
    });
  });

  group('T-0038-AC2 scenarios', () {
    test('T-0038-AC2: comics.empty empties every endpoint', () async {
      final backend = _backend()..useScenario('comics.empty');
      final dio = backend.createDio();
      expect(await _get(dio, '/v1/comics'), {
        'offset': 0,
        'limit': 20,
        'total': 0,
        'count': 0,
        'results': <Object?>[],
      });
      expect(
        (await _get(dio, '/v1/comics?limit=0'))['error'],
        containsPair('parameter', 'limit'),
        reason: 'the empty list still validates',
      );
      expect(
        (await _get(dio, '/v1/comics/500000'))['error'],
        containsPair('id', '500000'),
      );
      expect(
        (await _get(dio, '/v1/series/400000'))['error'],
        containsPair('code', 'series_not_found'),
      );
    });

    test(
      'T-0038-AC2: comics.server_error fails every endpoint with 500',
      () async {
        final backend = _backend()..useScenario('comics.server_error');
        final dio = backend.createDio();
        for (final path in [
          '/v1/comics',
          '/v1/comics/500000',
          '/v1/series/400000',
        ]) {
          final response = await dio.get<Object?>(
            path,
            options: Options(validateStatus: (_) => true),
          );
          expect(response.statusCode, 500, reason: path);
        }
        backend.useScenario(null);
        expect((await _get(dio, '/v1/comics'))['total'], _comicCount);
      },
    );
  });
}
