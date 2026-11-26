// T-0038 Verifier probes (temporary; copied to documents/evidence/T-0038/verifier/).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Dio _dio({int seed = 42, List<MockDomain>? domains}) =>
    MockBackend(seed: seed, domains: domains ?? [const ComicsMockDomain()])
        .createDio();

Future<(int, Map<String, Object?>, String)> _get(Dio dio, String path) async {
  final r = await dio.get<String>(
    path,
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  return (
    r.statusCode!,
    jsonDecode(r.data!) as Map<String, Object?>,
    r.data!,
  );
}

List<Map<String, Object?>> _res(Map<String, Object?> b) =>
    (b['results']! as List).cast<Map<String, Object?>>();

void main() {
  group('VP titleStartsWith', () {
    test('VP1 case, whitespace, empty, unicode, punctuation', () async {
      final dio = _dio();
      Future<int> total(String q) async {
        final (s, b, _) = await _get(
          dio,
          '/v1/comics?titleStartsWith=${Uri.encodeQueryComponent(q)}&limit=1',
        );
        expect(s, 200, reason: q);
        return b['total']! as int;
      }

      expect(await total('spi'), 400);
      expect(await total('SPI'), 400);
      expect(await total('sPi'), 400);
      expect(await total('  spi  '), 400);
      expect(await total(''), 2400);
      expect(await total('   '), 2400);
      expect(await total('spa'), 200);
      expect(await total('é'), 0);
      expect(await total('Ü'), 0);
      expect(await total('日本'), 0);
      expect(await total('#'), 0);
      expect(await total('amber chronicles #1'), 11);
      expect(await total('AMBER CHRONICLES #20'), 1);
      expect(await total('amber chronicles #1 '), 11, reason: 'trimmed');
    });
  });

  group('VP characterId', () {
    test('VP2 unknown, non-numeric, overflow, padded, combined', () async {
      final dio = _dio();
      for (final (q, status) in const [
        ('1', 200),
        ('0', 200),
        ('101500', 200),
        ('0100000', 200),
        ('x', 400),
        ('', 400),
        ('-1', 400),
        ('1.5', 400),
        ('+5', 400),
        (' 100000', 400),
        ('0x10', 400),
        ('99999999999999999999999', 400),
      ]) {
        final (s, b, _) = await _get(
          dio,
          '/v1/comics?characterId=${Uri.encodeQueryComponent(q)}',
        );
        expect(s, status, reason: 'characterId="$q"');
        if (s == 400) {
          expect(b['error'], {
            'code': 'invalid_parameter',
            'message': 'Query parameter "characterId" must be an integer id',
            'parameter': 'characterId',
          });
        }
      }
      expect((await _get(dio, '/v1/comics?characterId=1')).$2['total'], 0);
      expect(
        (await _get(dio, '/v1/comics?characterId=101500')).$2['total'],
        0,
      );
      expect(
        (await _get(dio, '/v1/comics?characterId=0100000')).$2['total'],
        6,
        reason: 'leading zeros parse like characters ids do',
      );
      // Combined filters.
      final all = _res(
        (await _get(dio, '/v1/comics?characterId=100000&limit=100')).$2,
      );
      final prefix = (all.first['title']! as String).substring(0, 3);
      final both = (await _get(
        dio,
        '/v1/comics?characterId=100000&titleStartsWith=$prefix&limit=100',
      ))
          .$2;
      expect(both['total'], [
        for (final c in all)
          if ((c['title']! as String).toLowerCase().startsWith(
            prefix.toLowerCase(),
          ))
            c,
      ].length);
    });

    test('VP3 reverse lookup is complete for every character', () async {
      final u = ComicUniverse(42);
      var links = 0;
      final counts = <int, int>{};
      for (final c in u.byTitle) {
        for (final id in c.characterIds) {
          links++;
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      var sum = 0;
      for (var id = characterIdBase; id < characterIdBase + characterIdCount;
          id++) {
        final n = u.comicsOfCharacter(id).length;
        expect(n, counts[id] ?? 0, reason: '$id');
        sum += n;
      }
      expect(sum, links);
    });
  });

  group('VP offset/limit', () {
    test('VP4 boundaries, above max, negative, overflow, empty', () async {
      final dio = _dio();
      for (final (q, status, count) in const [
        ('limit=1', 200, 1),
        ('limit=100', 200, 100),
        ('limit=101', 400, -1),
        ('limit=0', 400, -1),
        ('limit=-5', 400, -1),
        ('limit=', 400, -1),
        ('limit=1e2', 400, -1),
        ('offset=0', 200, 20),
        ('offset=2399', 200, 1),
        ('offset=2400', 200, 0),
        ('offset=1000000000000', 200, 0),
        ('offset=-1', 400, -1),
        ('offset=', 400, -1),
        ('offset=99999999999999999999999', 400, -1),
        ('orderBy=', 400, -1),
        ('orderBy=TITLE', 400, -1),
        ('orderBy=name', 400, -1),
      ]) {
        final (s, b, _) = await _get(dio, '/v1/comics?$q');
        expect(s, status, reason: q);
        if (s == 200) {
          expect(b['count'], count, reason: q);
          expect(b['total'], 2400, reason: q);
        } else {
          expect((b['error']! as Map)['code'], 'invalid_parameter');
          expect(
            (b['error']! as Map)['parameter'],
            q.split('=').first,
            reason: q,
          );
        }
      }
    });

    test('VP5 every orderBy pages stably and totally, any page size',
        () async {
      final dio = _dio();
      final other = _dio();
      for (final order in ['title', '-title', 'releaseDate', '-releaseDate']) {
        for (final filter in ['', '&titleStartsWith=spi', '&characterId=100007']) {
          Future<List<int>> walk(Dio d, int limit) async {
            final ids = <int>[];
            int? total;
            for (var offset = 0;; offset += limit) {
              final (s, b, _) = await _get(
                d,
                '/v1/comics?offset=$offset&limit=$limit&orderBy=$order$filter',
              );
              expect(s, 200);
              total ??= b['total']! as int;
              expect(b['total'], total, reason: 'total stable');
              final page = _res(b);
              if (page.isEmpty) break;
              ids.addAll([for (final c in page) c['id']! as int]);
            }
            expect(ids, hasLength(total), reason: '$order$filter');
            expect(ids.toSet(), hasLength(total), reason: '$order$filter');
            return ids;
          }

          final a = await walk(dio, 100);
          final b = await walk(dio, 7);
          final c = await walk(other, 33);
          expect(b, a, reason: '$order$filter page size 7');
          expect(c, a, reason: '$order$filter other backend');
        }
      }
      // -title is exactly the reverse of title (titles are unique).
      Future<List<int>> all(String order) async {
        final ids = <int>[];
        for (var o = 0; o < 2400; o += 100) {
          ids.addAll([
            for (final c in _res(
              (await _get(dio, '/v1/comics?offset=$o&limit=100&orderBy=$order'))
                  .$2,
            ))
              c['id']! as int,
          ]);
        }
        return ids;
      }

      expect(await all('-title'), (await all('title')).reversed.toList());
      // releaseDate: ties break on ascending id in both directions.
      final u = ComicUniverse(42);
      final byId = {for (final c in u.byTitle) c.id: c};
      final asc = await all('releaseDate');
      for (var i = 1; i < asc.length; i++) {
        final p = byId[asc[i - 1]]!, q = byId[asc[i]]!;
        final cmp = p.releaseDate.compareTo(q.releaseDate);
        expect(cmp < 0 || (cmp == 0 && p.id < q.id), isTrue);
      }
      final desc = await all('-releaseDate');
      var ties = 0;
      for (var i = 1; i < desc.length; i++) {
        final p = byId[desc[i - 1]]!, q = byId[desc[i]]!;
        final cmp = q.releaseDate.compareTo(p.releaseDate);
        if (cmp == 0) ties++;
        expect(cmp < 0 || (cmp == 0 && p.id < q.id), isTrue);
      }
      expect(ties, greaterThan(0), reason: 'the tie-break is exercised');
    });
  });

  group('VP determinism', () {
    test('VP6 request order does not change a response', () async {
      final a = _dio();
      final b = _dio();
      const paths = [
        '/v1/comics/501234',
        '/v1/series/400077',
        '/v1/comics?orderBy=-releaseDate&limit=100',
      ];
      final first = [for (final p in paths) (await _get(a, p)).$3];
      // Warm b with other traffic first, then ask in reverse order.
      for (var i = 0; i < 20; i++) {
        await _get(b, '/v1/comics/${500000 + i}');
      }
      final second = [for (final p in paths.reversed) (await _get(b, p)).$3];
      expect(second.reversed.toList(), first);
    });

    test('VP7 another seed changes every non-name field family', () async {
      final a = _dio();
      final b = _dio(seed: 7);
      final (_, d42, raw42) = await _get(a, '/v1/comics/500000');
      final (_, d7, raw7) = await _get(b, '/v1/comics/500000');
      expect(raw42, isNot(raw7));
      expect(d42['title'], d7['title']);
      final s42 = (await _get(a, '/v1/series/400000')).$3;
      final s7 = (await _get(b, '/v1/series/400000')).$3;
      expect(s42, isNot(s7));
      final l42 = (await _get(a, '/v1/comics?limit=100')).$3;
      final l7 = (await _get(b, '/v1/comics?limit=100')).$3;
      expect(l42, isNot(l7));
      // Same seed, twice in one process, also equal for a 3rd seed.
      expect((await _get(_dio(seed: 7), '/v1/comics/500000')).$3, raw7);
    });
  });

  group('VP errors and consistency with characters', () {
    test('VP8 404 bodies name the raw id; shapes match characters', () async {
      final dio = _dio(
        domains: [const ComicsMockDomain(), const CharactersMockDomain()],
      );
      for (final raw in ['1', 'abc', '502400', '000', 'caf%C3%A9']) {
        final (s, b, _) = await _get(dio, '/v1/comics/$raw');
        expect(s, 404);
        final e = b['error']! as Map;
        expect(e.keys.toSet(), {'code', 'message', 'id'});
        expect(e['message'], 'No comic with id ${e['id']}');
        final (cs, cb, _) = await _get(dio, '/v1/characters/$raw');
        expect(cs, 404);
        expect(
          (cb['error']! as Map)['id'],
          e['id'],
          reason: 'raw id echoed the same way in both domains ($raw)',
        );
        final (ss, sb, _) = await _get(dio, '/v1/series/$raw');
        expect(ss, 404);
        expect((sb['error']! as Map)['id'], e['id']);
        expect((sb['error']! as Map)['code'], 'series_not_found');
      }
      // Leading zeros resolve, as in characters.
      expect((await _get(dio, '/v1/comics/0500000')).$1, 200);
      expect((await _get(dio, '/v1/characters/0100000')).$1, 200);
      // 400 bodies are byte-identical between domains for a shared rule.
      for (final q in ['limit=0', 'limit=101', 'offset=-1']) {
        final c = (await _get(dio, '/v1/comics?$q')).$2;
        final h = (await _get(dio, '/v1/characters?$q')).$2;
        expect(c, h, reason: q);
      }
      // Engine 404 for a path below a detail route.
      final (es, eb, _) = await _get(dio, '/v1/comics/1/extra');
      expect(es, 404);
      expect((eb['error']! as Map)['code'], 'not_found');
    });

    test('VP9 server_error scenario vs set, empty scenario keeps 400s',
        () async {
      final backend = MockBackend(
        domains: [const ComicsMockDomain(), const CharactersMockDomain()],
      );
      final dio = backend.createDio();
      backend.useScenario('comics.server_error');
      final scen = (await _get(dio, '/v1/comics')).$2['error']! as Map;
      backend.useScenario('characters.server_error');
      final chars = (await _get(dio, '/v1/characters')).$2['error']! as Map;
      expect(scen['code'], chars['code']);
      // ignore: avoid_print
      print('scenario code=${scen['code']} characters code=${chars['code']}');
      final set = (await _get(_dio(domains: [const FailingComicsDomain()]),
              '/v1/comics'))
          .$2['error']! as Map;
      // ignore: avoid_print
      print('set code=${set['code']}');
      backend.useScenario('comics.empty');
      expect((await _get(dio, '/v1/comics?characterId=x')).$1, 400);
      expect((await _get(dio, '/v1/comics?characterId=100000')).$2['total'], 0);
      // The empty scenario does not touch characters.
      expect((await _get(dio, '/v1/characters')).$2['total'], 1500);
    });
  });

  group('VP data shape over all 2,400 comics', () {
    test('VP10 documented invariants hold for every comic', () async {
      final dio = _dio();
      final names = <String>{};
      for (var id = 500000; id < 502400; id++) {
        final (s, d, _) = await _get(dio, '/v1/comics/$id');
        expect(s, 200);
        final series = d['series']! as Map;
        expect(series['id'], d['seriesId']);
        final creators = (d['creators']! as List).cast<Map>();
        expect(creators.length, inInclusiveRange(2, 6));
        const roles = [
          'writer',
          'penciller',
          'inker',
          'colorist',
          'letterer',
          'cover_artist',
        ];
        expect([for (final c in creators) c['role']],
            roles.sublist(0, creators.length));
        for (final c in creators) {
          expect(c['id'], inInclusiveRange(300000, 300059));
          names.add(c['name']! as String);
        }
        final ids = (d['characterIds']! as List).cast<int>();
        expect(ids.length, inInclusiveRange(1, 6));
        expect(ids, [...ids]..sort());
        expect(ids.toSet(), hasLength(ids.length));
        final price = d['price']! as Map;
        expect(price['currency'], 'USD');
        expect([299, 399, 499, 599], contains(price['amountCents']));
        expect([24, 32, 40, 48, 56], contains(d['pageCount']));
        final variants = (d['variants']! as List).cast<Map>();
        expect(variants.length, inInclusiveRange(0, 2));
        expect({for (final v in variants) v['label']}, hasLength(variants.length));
        expect(d['title'], '${series['title']} #${d['issueNumber']}');
      }
      // ignore: avoid_print
      print('creator names in use (${names.length}): ${names.toList()..sort()}');
      final series = <String>[];
      for (var s = 400000; s < 400120; s++) {
        series.add((await _get(dio, '/v1/series/$s')).$2['title']! as String);
      }
      expect(series.toSet(), hasLength(120));
      // ignore: avoid_print
      print('series titles: $series');
    });

    test('VP11 every distinct characterId is a 200 on the real characters '
        'route, for seeds 42 and 7', () async {
      for (final seed in [42, 7]) {
        final dio = _dio(
          seed: seed,
          domains: [const ComicsMockDomain(), const CharactersMockDomain()],
        );
        final ids = <int>{};
        for (var id = 500000; id < 502400; id++) {
          ids.addAll(
            ((await _get(dio, '/v1/comics/$id')).$2['characterIds']! as List)
                .cast<int>(),
          );
        }
        for (final id in ids) {
          final (s, b, _) = await _get(dio, '/v1/characters/$id');
          expect(s, 200, reason: 'seed $seed character $id');
          expect(b['id'], id);
        }
        // ignore: avoid_print
        print('seed $seed: ${ids.length} distinct characters linked, all 200');
      }
    });
  });
}
