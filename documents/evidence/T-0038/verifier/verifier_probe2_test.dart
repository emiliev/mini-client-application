// T-0038 Verifier re-verification probes at 38354b9 (temporary in the package;
// kept here as evidence). Run with run_probes2.sh.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

List<String> _titles(Map<String, Object?> b) => [
  for (final c in (b['results']! as List).cast<Map<String, Object?>>())
    c['title']! as String,
];

(String, int) _key(String title) {
  final i = title.lastIndexOf(' #');
  return (title.substring(0, i), int.parse(title.substring(i + 2)));
}

Future<List<String>> _walk(Dio dio, String query, int limit) async {
  final out = <String>[];
  for (var offset = 0;; offset += limit) {
    final (s, b, _) = await _get(
      dio,
      '/v1/comics?offset=$offset&limit=$limit$query',
    );
    expect(s, 200);
    final t = _titles(b);
    if (t.isEmpty) break;
    out.addAll(t);
  }
  return out;
}

void _expectIssueOrder(List<String> titles, {required bool descending}) {
  for (var i = 1; i < titles.length; i++) {
    final p = _key(titles[i - 1]), q = _key(titles[i]);
    final bySeries = p.$1.compareTo(q.$1);
    final cmp = bySeries != 0 ? bySeries : p.$2.compareTo(q.$2);
    expect(
      descending ? cmp > 0 : cmp < 0,
      isTrue,
      reason: '${titles[i - 1]} then ${titles[i]}',
    );
  }
}

void main() {
  test('RV1 title and -title: issue order, series boundaries, filters',
      () async {
    final dio = _dio();
    // Paging across a series boundary, ascending.
    expect(_titles((await _get(dio, '/v1/comics?offset=19&limit=2')).$2), [
      'Amber Chronicles #20',
      'Amber Crossing #1',
    ]);
    expect(_titles((await _get(dio, '/v1/comics?offset=38&limit=4')).$2), [
      'Amber Crossing #19',
      'Amber Crossing #20',
      'Amber Frontier #1',
      'Amber Frontier #2',
    ]);
    // Descending starts at the last series' last issue and crosses too.
    expect(
      _titles((await _get(dio, '/v1/comics?orderBy=-title&limit=2')).$2),
      ['Spire Vanguard #20', 'Spire Vanguard #19'],
    );
    expect(
      _titles(
        (await _get(dio, '/v1/comics?orderBy=-title&offset=19&limit=2')).$2,
      ),
      ['Spire Vanguard #1', 'Spire Station #20'],
    );
    // Whole listings, several page sizes, both orders, with and without a
    // filter: strictly in (series, issue) order, complete, the same walks.
    for (final filter in ['', '&titleStartsWith=spi', '&titleStartsWith=AMBER%20c',
        '&characterId=100007']) {
      final asc = await _walk(dio, filter, 100);
      final asc7 = await _walk(dio, filter, 7);
      final desc = await _walk(dio, '$filter&orderBy=-title', 13);
      expect(asc7, asc, reason: filter);
      expect(desc, asc.reversed.toList(), reason: filter);
      _expectIssueOrder(asc, descending: false);
      _expectIssueOrder(desc, descending: true);
      final total = (await _get(dio, '/v1/comics?limit=1$filter')).$2['total'];
      expect(asc, hasLength(total), reason: filter);
    }
    final amberC = await _walk(dio, '&titleStartsWith=amber%20c', 100);
    expect(amberC, [
      for (var i = 1; i <= 20; i++) 'Amber Chronicles #$i',
      for (var i = 1; i <= 20; i++) 'Amber Crossing #$i',
    ]);
    // titleStartsWith still matches '#1' as a text prefix of the title.
    expect(
      (await _get(dio, '/v1/comics?titleStartsWith=amber%20chronicles%20%231'))
          .$2['total'],
      11,
    );
  });

  test('RV2 vocabulary: no Gambit or Iron, 10 surnames, 60 unique names',
      () async {
    final dio = _dio();
    final series = <String>[];
    for (var s = 400000; s < 400120; s++) {
      series.add((await _get(dio, '/v1/series/$s')).$2['title']! as String);
    }
    expect(series.toSet(), hasLength(120));
    for (final w in ['Gambit', 'Iron', 'Man', 'Spider', 'X-', 'Avenger',
        'Hulk', 'Thor', 'Marvel', 'Vision', 'Legion', 'Storm', 'Phoenix']) {
      expect(series.where((t) => t.contains(w)), isEmpty, reason: w);
    }
    final names = <String>{};
    for (var id = 500000; id < 502400; id++) {
      for (final c in ((await _get(dio, '/v1/comics/$id')).$2['creators']!
              as List)
          .cast<Map<String, Object?>>()) {
        names.add(c['name']! as String);
      }
    }
    expect(names, hasLength(60));
    expect({for (final n in names) n.split(' ').last}, hasLength(10));
    // ignore: avoid_print
    print('series: $series');
    // ignore: avoid_print
    print('creators: ${names.toList()..sort()}');
  });

  test('RV3 the documented seed-independent fields are seed-independent',
      () async {
    final a = _dio();
    final b = _dio(seed: 7);
    var differ = 0;
    for (final id in [500000, 500061, 501500, 502399]) {
      final x = (await _get(a, '/v1/comics/$id')).$2;
      final y = (await _get(b, '/v1/comics/$id')).$2;
      for (final k in ['id', 'issueNumber', 'title', 'seriesId', 'series']) {
        expect(y[k], x[k], reason: '$id $k');
      }
      for (final k in ['description', 'releaseDate', 'price', 'pageCount',
          'creators', 'characterIds', 'variants', 'cover']) {
        if (jsonEncode(x[k]) != jsonEncode(y[k])) differ++;
      }
    }
    expect(differ, greaterThan(20));
    for (final id in [400000, 400075, 400119]) {
      final x = (await _get(a, '/v1/series/$id')).$2;
      final y = (await _get(b, '/v1/series/$id')).$2;
      for (final k in ['id', 'title', 'cover', 'comicIds', 'comicCount']) {
        expect(y[k], x[k], reason: '$id $k');
      }
    }
    // Title order (and so every title page) is seed-independent.
    expect(
      (await _get(b, '/v1/comics?offset=40&limit=2')).$2['results'].toString()
          .contains('Amber Frontier #1'),
      isTrue,
    );
  });

  test('RV4 server_error: set and scenario bodies identical on 3 routes',
      () async {
    final backend = MockBackend(domains: [const ComicsMockDomain()])
      ..useScenario('comics.server_error');
    final scen = backend.createDio();
    final set = _dio(domains: [comicsFixtureSets['comics.server_error']!()]);
    for (final p in ['/v1/comics?limit=3', '/v1/comics/123', '/v1/series/x']) {
      final (s1, _, raw1) = await _get(scen, p);
      final (s2, _, raw2) = await _get(set, p);
      expect((s1, raw1), (s2, raw2), reason: p);
      expect(s1, 500);
      // ignore: avoid_print
      print('$p -> $s1 $raw1');
    }
  });
}
