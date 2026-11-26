import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockBackend _backend({int seed = 42, List<MockDomain>? domains}) => MockBackend(
  seed: seed,
  domains: domains ?? [const DiscoveryMockDomain()],
);

Future<Response<String>> _res(Dio dio, String path) => dio.get<String>(
  path,
  options: Options(
    responseType: ResponseType.plain,
    validateStatus: (_) => true,
  ),
);

/// The raw body text of a GET, whatever the status.
Future<String> _raw(Dio dio, String path) async {
  final response = await _res(dio, path);
  return '${response.statusCode} ${response.data}';
}

Future<Map<String, Object?>> _get(Dio dio, String path) async {
  final response = await dio.get<Map<String, Object?>>(
    path,
    options: Options(validateStatus: (_) => true),
  );
  return response.data!;
}

List<Map<String, Object?>> _groups(Map<String, Object?> body) =>
    (body['groups']! as List).cast<Map<String, Object?>>();

List<Map<String, Object?>> _results(Map<String, Object?> group) =>
    (group['results']! as List).cast<Map<String, Object?>>();

Map<String, Object?> _error(Map<String, Object?> body) =>
    body['error']! as Map<String, Object?>;

/// An independent oracle for the tier of [title] against the lower-case,
/// ASCII query [q] (the real titles are ASCII). 0 exact, 1 prefix, 2 word
/// prefix, 3 substring, -1 no match.
int _tierOf(String title, String q) {
  final t = title.toLowerCase();
  if (t == q) {
    return 0;
  }
  if (t.startsWith(q)) {
    return 1;
  }
  if (RegExp('[^a-z0-9]${RegExp.escape(q)}').hasMatch(t)) {
    return 2;
  }
  return t.contains(q) ? 3 : -1;
}

/// The expected ranking of one domain, built from the universes themselves:
/// (tier, title, id).
List<(int, String, int)> _oracle(Iterable<(String, int)> items, String q) {
  final out = <(int, String, int)>[
    for (final (title, id) in items)
      if (_tierOf(title, q) >= 0) (_tierOf(title, q), title, id),
  ];
  out.sort((a, b) {
    for (final c in [a.$1.compareTo(b.$1), a.$2.compareTo(b.$2)]) {
      if (c != 0) {
        return c;
      }
    }
    return a.$3.compareTo(b.$3);
  });
  return out;
}

Iterable<(String, int)> _characters() => [
  for (final c in CharacterUniverse(42, defaultMockClock).byName)
    (c.name, c.id),
];

Iterable<(String, int)> _comics() => [
  for (final c in ComicUniverse(42).byTitle) (c.title, c.id),
];

SearchEntry _entry(int id, String title, {String type = 'character'}) =>
    SearchEntry(
      id: id,
      type: type,
      title: title,
      thumbnail: ApiImage(path: 'mock-asset://characters/000'),
    );

void main() {
  group('T-0043-AC1 determinism', () {
    const sequence = [
      '/v1/search?q=spi',
      '/v1/search?q=spire&limit=5',
      '/v1/search?q=Spire%20Warden',
      '/v1/search?q=co&limit=100',
      '/v1/search?q=chron&types=comic&limit=50',
      '/v1/search?q=war&types=character',
      '/v1/search?q=zzzz',
      '/v1/search?q=s',
      '/v1/search?q=spi&types=film',
      '/v1/search?q=spi&limit=0',
      '/v1/search/suggestions?q=spi',
      '/v1/search/suggestions?q=chron',
      '/v1/search/suggestions?q=x',
    ];

    test(
      'T-0043-AC1: seed 42 gives byte-identical responses on two backends',
      () async {
        final a = _backend().createDio();
        final b = _backend().createDio();
        var bytes = 0;
        for (final path in sequence) {
          final first = await _raw(a, path);
          expect(first, await _raw(b, path), reason: path);
          // A repeat on the same backend is the same too (no hidden state).
          expect(first, await _raw(a, path), reason: '$path (repeat)');
          bytes += first.length;
        }
        expect(bytes, greaterThan(20000));
      },
    );

    test('T-0043-AC1: the seed changes only what depends on it', () async {
      final a = await _raw(_backend().createDio(), '/v1/search?q=spire');
      final other = await _raw(
        _backend(seed: 7).createDio(),
        '/v1/search?q=spire',
      );
      // Names, comic titles and ids do not depend on the seed; the art does.
      expect(other, isNot(a));
      final titles = [
        for (final g in _groups(
          await _get(_backend(seed: 7).createDio(), '/v1/search?q=spire'),
        ))
          for (final r in _results(g)) r['title'],
      ];
      final titles42 = [
        for (final g in _groups(
          await _get(_backend().createDio(), '/v1/search?q=spire'),
        ))
          for (final r in _results(g)) r['title'],
      ];
      expect(titles, titles42);
    });
  });

  group('T-0043-AC2 ranking through the endpoint', () {
    late Dio dio;
    setUp(() => dio = _backend().createDio());

    test(
      'T-0043-AC2: q=spi gives character then comic groups, all matching',
      () async {
        final body = await _get(dio, '/v1/search?q=spi&limit=100');
        expect(body['query'], 'spi');
        final groups = _groups(body);
        expect([for (final g in groups) g['type']], ['character', 'comic']);
        expect([for (final g in groups) g['total']], [152, 400]);
        for (final group in groups) {
          final results = _results(group);
          expect(results, hasLength(100));
          for (final r in results) {
            expect(r['type'], group['type']);
            expect(
              _tierOf(r['title']! as String, 'spi'),
              greaterThanOrEqualTo(1),
              reason: '${r['title']} must match "spi"',
            );
          }
        }
      },
    );

    test('T-0043-AC2: P1-10 AC5 a curated name returns hits from both domains, '
        'ranked the same way every time', () async {
      final first = await _get(dio, '/v1/search?q=spindle');
      final again = await _get(_backend().createDio(), '/v1/search?q=spindle');
      expect(again, first);
      final groups = _groups(first);
      expect([for (final g in groups) g['type']], ['character', 'comic']);
      expect([for (final g in groups) _results(g).isNotEmpty], [true, true]);
      expect(_results(groups[0]).first['title'], 'Spindle Alchemist');
      expect(_results(groups[1]).first['title'], 'Spindle Chronicles #1');
    });

    for (final q in [
      'spi',
      'co',
      'war',
      'chron',
      'amber chronicles #1',
      'ber',
    ]) {
      test('T-0043-AC2: "$q" is ranked like the independent oracle '
          '(tier, title, id) in both groups', () async {
        final body = await _get(
          dio,
          '/v1/search?q=${Uri.encodeQueryComponent(q)}&limit=100',
        );
        final groups = _groups(body);
        for (final (index, items) in [_characters(), _comics()].indexed) {
          final expected = _oracle(items, q);
          expect(groups[index]['total'], expected.length, reason: q);
          expect(
            [for (final r in _results(groups[index])) r['id']],
            [for (final e in expected.take(100)) e.$3],
            reason: q,
          );
        }
      });
    }

    test('T-0043-AC2: the facts CONTRACT.md lists for seed 42 hold', () async {
      Future<List<Object?>> totals(String path) async => [
        for (final g in _groups(await _get(dio, path))) g['total'],
      ];
      expect(await totals('/v1/search?q=Spire%20Warden'), [1, 0]);
      expect(await totals('/v1/search?q=chron'), [0, 240]);
      expect(await totals('/v1/search?q=ard&types=character'), [160]);
      expect(await totals('/v1/search?q=spindle'), [38, 200]);
      final spire = _groups(await _get(dio, '/v1/search?q=Spire%20Warden'));
      expect(_results(spire[0]).single['title'], 'Spire Warden');
      expect(_results(spire[1]), isEmpty);
      final spindle = _groups(await _get(dio, '/v1/search?q=spindle&limit=2'));
      expect(
        [for (final r in _results(spindle[0])) r['title']],
        [
          'Spindle Alchemist',
          'Spindle Artisan',
        ],
      );
      final suggestions = await _get(dio, '/v1/search/suggestions?q=spi');
      expect(suggestions['suggestions'], [
        'Spindle Alchemist',
        'Spindle Artisan',
        'Spindle Bard',
        'Spindle Beacon',
        'Spindle Captain',
      ]);
    });

    test('T-0043-AC2: all four tiers show up in order on the real data', () async {
      // "co": names starting with co, then a later word starting with co, then
      // the rest.
      final body = await _get(dio, '/v1/search?q=co&types=character&limit=100');
      final tiers = [
        for (final r in _results(_groups(body).single))
          _tierOf(r['title']! as String, 'co'),
      ];
      expect(tiers.toSet(), {1, 2, 3});
      expect([...tiers]..sort(), tiers);
      // "amber chronicles #1": the exact title, then the #1x issues.
      final exact = await _get(
        dio,
        '/v1/search?q=amber%20chronicles%20%231&types=comic',
      );
      final titles = [
        for (final r in _results(_groups(exact).single)) r['title'],
      ];
      expect(titles.first, 'Amber Chronicles #1');
      expect(titles.skip(1), everyElement(startsWith('Amber Chronicles #1')));
      expect(titles, hasLength(11));
    });

    test('T-0043-AC2: case, diacritics and padding in q do not change the '
        'results', () async {
      final plain = _groups(await _get(dio, '/v1/search?q=spire'));
      for (final q in ['SPIRE', 'Spïre', '%20%20spire%20', 'spiré']) {
        final other = _groups(await _get(dio, '/v1/search?q=$q'));
        expect(other, plain, reason: q);
      }
      expect(await _get(dio, '/v1/search?q=%20Spïre%20'), {
        ...await _get(dio, '/v1/search?q=Spïre'),
      });
      expect((await _get(dio, '/v1/search?q=%20Spïre%20'))['query'], 'Spïre');
    });

    test(
      'T-0043-AC2: groups keep the fixed order whatever order types asks',
      () async {
        final body = await _get(dio, '/v1/search?q=spi&types=comic,character');
        expect(
          [for (final g in _groups(body)) g['type']],
          [
            'character',
            'comic',
          ],
        );
        final one = await _get(dio, '/v1/search?q=spi&types=comic');
        expect([for (final g in _groups(one)) g['type']], ['comic']);
        // Repeats and spaces collapse to one group.
        final twice = await _get(dio, '/v1/search?q=spi&types=comic,%20comic');
        expect(_groups(twice), hasLength(1));
      },
    );

    test(
      'T-0043-AC2: a group is present, with total 0, when nothing matches',
      () async {
        final body = await _get(dio, '/v1/search?q=zzzz');
        expect(body, {
          'query': 'zzzz',
          'groups': [
            {'type': 'character', 'total': 0, 'results': <Object?>[]},
            {'type': 'comic', 'total': 0, 'results': <Object?>[]},
          ],
        });
      },
    );

    test(
      'T-0043-AC2: a result has id, type, title, subtitle and thumbnail',
      () async {
        final body = await _get(dio, '/v1/search?q=spire&limit=1');
        final character = _results(_groups(body)[0]).single;
        final comic = _results(_groups(body)[1]).single;
        expect(character.keys.toSet(), {
          'id',
          'type',
          'title',
          'subtitle',
          'thumbnail',
        });
        expect(character['type'], 'character');
        expect(comic['type'], 'comic');
        expect(comic['subtitle'], matches(RegExp(r'^\d{4}$')));
        for (final r in [character, comic]) {
          expect(
            r['thumbnail'],
            containsPair('path', startsWith('mock-asset://')),
          );
        }
      },
    );
  });

  group('T-0043-AC2 tie-breaks through the endpoint', () {
    Dio indexed(List<SearchEntry> entries) =>
        _backend(domains: [IndexedDiscoveryDomain(SearchIndex(entries))])
            .createDio();

    test(
      'T-0043-AC2: same-tier results go by title, then id, then type',
      () async {
        final dio = indexed([
          _entry(9, 'Alpha'),
          _entry(1, 'Alpha', type: 'comic'),
          _entry(3, 'Alpha'),
          _entry(2, 'Alpha Aardvark'),
          _entry(4, 'Alpha Zebra'),
        ]);
        final both = await _get(dio, '/v1/search?q=alp');
        final groups = _groups(both);
        expect([for (final r in _results(groups[0])) r['id']], [3, 9, 2, 4]);
        expect([for (final r in _results(groups[1])) r['id']], [1]);
      },
    );

    test(
      'T-0043-AC2: suggestions rank across types by tier, title and type',
      () async {
        final dio = indexed([
          _entry(1, 'Kalpa'),
          _entry(2, 'Zeta Alp', type: 'comic'),
          _entry(3, 'Alpha Zulu', type: 'comic'),
          _entry(4, 'Alpha Bee'),
          _entry(5, 'Alp'),
          _entry(6, 'Alp', type: 'comic'),
        ]);
        final body = await _get(dio, '/v1/search/suggestions?q=alp');
        // Alp (exact; the character and the comic share one title), the two
        // prefix titles by title, then the word-prefix, then the substring.
        expect(body['suggestions'], [
          'Alp',
          'Alpha Bee',
          'Alpha Zulu',
          'Zeta Alp',
          'Kalpa',
        ]);
      },
    );

    test(
      'T-0043-AC2: suggestions stop at five and skip repeated titles',
      () async {
        final dio = indexed([
          for (var i = 0; i < 8; i++) _entry(i, 'Alpha $i'),
          _entry(20, 'Alpha 0', type: 'comic'),
        ]);
        final body = await _get(dio, '/v1/search/suggestions?q=alp');
        expect(body['suggestions'], [
          'Alpha 0',
          'Alpha 1',
          'Alpha 2',
          'Alpha 3',
          'Alpha 4',
        ]);
      },
    );
  });

  group('T-0043-AC2 suggestions', () {
    test(
      'T-0043-AC2: the top 5 titles across types match the oracle',
      () async {
        final dio = _backend().createDio();
        for (final q in ['spi', 'chron', 'war', 'co', 'spire warden']) {
          final expected =
              [
                ..._oracle(_characters(), q).map((e) => (e.$1, e.$2, 0, e.$3)),
                ..._oracle(_comics(), q).map((e) => (e.$1, e.$2, 1, e.$3)),
              ]..sort((a, b) {
                for (final c in [
                  a.$1.compareTo(b.$1),
                  a.$2.compareTo(b.$2),
                  a.$3.compareTo(b.$3),
                  a.$4.compareTo(b.$4),
                ]) {
                  if (c != 0) {
                    return c;
                  }
                }
                return 0;
              });
          final titles = <String>[];
          for (final e in expected) {
            if (!titles.contains(e.$2) && titles.length < 5) {
              titles.add(e.$2);
            }
          }
          final body = await _get(
            dio,
            '/v1/search/suggestions?q=${Uri.encodeQueryComponent(q)}',
          );
          expect(body, {'query': q, 'suggestions': titles}, reason: q);
        }
      },
    );

    test(
      'T-0043-AC2: suggestions come from both domains when both match',
      () async {
        final dio = _backend().createDio();
        // Exact, then both domains' prefix titles: characters before comics.
        final body = await _get(dio, '/v1/search/suggestions?q=spire');
        expect((body['suggestions']! as List).first, startsWith('Spire '));
        final none = await _get(dio, '/v1/search/suggestions?q=zzzz');
        expect(none['suggestions'], isEmpty);
      },
    );
  });

  group('T-0043-AC4 validation', () {
    late Dio dio;
    setUp(() => dio = _backend().createDio());

    for (final path in [
      '/v1/search',
      '/v1/search?q=',
      '/v1/search?q=s',
      '/v1/search?q=%20s%20',
      '/v1/search?q=%20%20%20',
      '/v1/search?q=%C3%A9',
      '/v1/search/suggestions',
      '/v1/search/suggestions?q=a',
    ]) {
      test('T-0043-AC4: $path is 400 query_too_short', () async {
        final response = await _res(dio, path);
        expect(response.statusCode, 400);
        final error = _error(
          await _get(dio, path),
        );
        expect(error['code'], 'query_too_short');
        expect(error['parameter'], 'q');
        expect(error['minLength'], 2);
      });
    }

    test(
      'T-0043-AC4: two characters are enough, counted after trimming',
      () async {
        expect((await _res(dio, '/v1/search?q=sp')).statusCode, 200);
        expect((await _res(dio, '/v1/search?q=%20sp%20')).statusCode, 200);
        // One letter with a mark is one character, not two bytes.
        expect(
          (await _res(dio, '/v1/search?q=%C3%A9%C3%A9')).statusCode,
          200,
        );
        expect(
          (await _res(dio, '/v1/search/suggestions?q=sp')).statusCode,
          200,
        );
      },
    );

    for (final types in [
      'film',
      'character,film',
      'Character',
      '',
      ',',
      'comic,',
    ]) {
      test('T-0043-AC4: types="$types" is 400 invalid_parameter', () async {
        final response = await _res(dio, '/v1/search?q=spi&types=$types');
        expect(response.statusCode, 400);
        final error = _error(await _get(dio, '/v1/search?q=spi&types=$types'));
        expect(error['code'], 'invalid_parameter');
        expect(error['parameter'], 'types');
      });
    }

    for (final limit in ['0', '101', '-1', 'x', '', '1.5', '0x10', '%2B5']) {
      test('T-0043-AC4: limit="$limit" is 400 invalid_parameter', () async {
        final path = '/v1/search?q=spi&limit=$limit';
        expect((await _res(dio, path)).statusCode, 400);
        final error = _error(await _get(dio, path));
        expect(error['code'], 'invalid_parameter');
        expect(error['parameter'], 'limit');
      });
    }

    test(
      'T-0043-AC4: limit 1 and 100 are accepted and apply per group',
      () async {
        final one = _groups(await _get(dio, '/v1/search?q=spi&limit=1'));
        expect([for (final g in one) _results(g).length], [1, 1]);
        expect([for (final g in one) g['total']], [152, 400]);
        final hundred = _groups(await _get(dio, '/v1/search?q=spi&limit=100'));
        expect([for (final g in hundred) _results(g).length], [100, 100]);
        final byDefault = _groups(await _get(dio, '/v1/search?q=spi'));
        expect([for (final g in byDefault) _results(g).length], [20, 20]);
      },
    );

    test(
      'T-0043-AC4: the first problem reported is q, then types, then limit',
      () async {
        final all = await _get(dio, '/v1/search?q=s&types=x&limit=0');
        expect(_error(all)['code'], 'query_too_short');
        final typesAndLimit = await _get(
          dio,
          '/v1/search?q=sp&types=x&limit=0',
        );
        expect(_error(typesAndLimit)['parameter'], 'types');
      },
    );

    test(
      'T-0043-AC4: a path outside the domain is the engine\'s 404',
      () async {
        final response = await _res(dio, '/v1/search/unknown?q=spi');
        expect(response.statusCode, 404);
      },
    );

    test('T-0043-AC4: the library entries serve only matching types', () async {
      final body = await _get(dio, '/v1/search?q=spi&types=character');
      expect([for (final g in _groups(body)) g['type']], ['character']);
    });
  });
}
