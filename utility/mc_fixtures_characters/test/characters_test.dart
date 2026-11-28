import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockBackend _backend({int seed = 42}) =>
    MockBackend(seed: seed, domains: [const CharactersMockDomain()]);

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

  group('T-0018-AC6 pagination', () {
    test('T-0018-AC6: offset 30 limit 30 is page 2 of 1,500', () async {
      final page = await _get(dio, '/v1/characters?offset=30&limit=30');
      expect(page['offset'], 30);
      expect(page['limit'], 30);
      expect(page['total'], 1500);
      expect(page['count'], 30);

      final names = [for (final c in _results(page)) c['name']! as String];
      final first = _results(await _get(dio, '/v1/characters?limit=60'));
      expect(names, [for (final c in first.skip(30)) c['name']]);
    });

    test(
      'T-0018-AC6: the order is stable, sorted and covers every character',
      () async {
        final seen = <int>{};
        String? previous;
        for (var offset = 0; offset < 1500; offset += 100) {
          final page = await _get(
            dio,
            '/v1/characters?offset=$offset&limit=100',
          );
          for (final c in _results(page)) {
            final name = c['name']! as String;
            if (previous != null)
              expect(name.compareTo(previous), greaterThan(0));
            previous = name;
            expect(
              seen.add(c['id']! as int),
              isTrue,
              reason: 'duplicate $name',
            );
          }
        }
        expect(seen, hasLength(1500));
        // A second backend with the same seed pages identically.
        final again = await _get(
          _backend().createDio(),
          '/v1/characters?offset=30&limit=30',
        );
        expect(again, await _get(dio, '/v1/characters?offset=30&limit=30'));
      },
    );

    test(
      'T-0018-AC6: the last page is short and past the end is empty',
      () async {
        final last = await _get(dio, '/v1/characters?offset=1490&limit=30');
        expect(last['count'], 10);
        final beyond = await _get(dio, '/v1/characters?offset=1500');
        expect(beyond['count'], 0);
        expect(beyond['total'], 1500);
      },
    );

    test('T-0018-AC6: invalid paging parameters are 400', () async {
      for (final query in [
        'limit=0',
        'limit=101',
        'offset=-1',
        'offset=x',
        'orderBy=age',
      ]) {
        final body = await _get(dio, '/v1/characters?$query');
        final error = body['error']! as Map<String, Object?>;
        expect(error['code'], 'invalid_parameter', reason: query);
      }
    });
  });

  group('T-0018-AC6 search', () {
    test('T-0018-AC6: nameStartsWith=spi matches names starting with spi, ignoring case', () async {
      for (final query in ['spi', 'SPI', 'Spi']) {
        final page = await _get(
          dio,
          '/v1/characters?nameStartsWith=$query&limit=100',
        );
        final total = page['total']! as int;
        expect(total, greaterThan(100));
        for (final c in _results(page)) {
          expect((c['name']! as String).toLowerCase(), startsWith('spi'));
        }
      }
      final all = await _get(
        dio,
        '/v1/characters?nameStartsWith=spi&limit=100&offset=100',
      );
      expect(all['count'], greaterThan(0));
      final none = await _get(dio, '/v1/characters?nameStartsWith=zzzz');
      expect(none['total'], 0);
      expect(none['results'], isEmpty);
    });

    test(
      'T-0018-AC6: other prefixes do not leak in (Sparrow is not spi)',
      () async {
        final page = await _get(
          dio,
          '/v1/characters?nameStartsWith=spa&limit=100',
        );
        expect(page['total'], greaterThan(0));
        for (final c in _results(page)) {
          expect(c['name'], startsWith('Spa'));
        }
      },
    );

    test('T-0018-AC6: orderBy -name reverses and ties break on id', () async {
      final asc = _results(await _get(dio, '/v1/characters?limit=100'));
      final desc = _results(
        await _get(dio, '/v1/characters?orderBy=-name&limit=100'),
      );
      expect(desc.first['name'], 'Zephyr Weaver');
      expect(asc.first['name'], 'Amber Alchemist');
      final modified = _results(
        await _get(dio, '/v1/characters?orderBy=modified&limit=100'),
      );
      for (var i = 1; i < modified.length; i++) {
        final a = modified[i - 1];
        final b = modified[i];
        final byDate = (a['modified']! as String).compareTo(
          b['modified']! as String,
        );
        expect(byDate <= 0, isTrue);
        if (byDate == 0) {
          expect(a['id']! as int, lessThan(b['id']! as int));
        }
      }
    });
  });

  group('T-0018-AC6 detail and universe', () {
    test('T-0018-AC6: detail by id, 404 for an unknown id', () async {
      final summary = _results(await _get(dio, '/v1/characters?limit=1'))
          .single;
      final detail = await _get(dio, '/v1/characters/${summary['id']}');
      expect(detail['name'], summary['name']);
      expect(detail['powers'], hasLength(3));
      expect(detail['appearances'], isA<Map<String, Object?>>());
      final missing = await _get(dio, '/v1/characters/42');
      expect((missing['error']! as Map)['code'], 'character_not_found');
    });

    test(
      'T-0067-AC1: the detail serves aliases and six stats, exactly',
      () async {
        final spirit = await _get(dio, '/v1/characters/100001');
        expect(spirit['aliases'], ['The Falconer', 'The Smith']);
        expect(spirit['stats'], {
          'combat': 28,
          'durability': 29,
          'energy': 79,
          'intelligence': 58,
          'speed': 89,
          'strength': 94,
        });
        final spindle = await _get(dio, '/v1/characters/100000');
        expect(
          spindle['aliases'],
          isEmpty,
          reason: 'a character may have none',
        );
        final spiral = await _get(dio, '/v1/characters/100002');
        expect(spiral['aliases'], ['The Sentinel']);
      },
    );

    test('T-0067-AC1: the new fields moved nothing that was served before', () {
      // The fields drawn before aliases and stats keep their seed-42 values.
      final spindle = CharacterUniverse(42, defaultMockClock).find(100000)!;
      expect(spindle.team, 'The Quiet Ones');
      expect(spindle.powers, ['Dream walking', 'Echo vision', 'Iron skin']);
      expect(spindle.firstAppearanceYear, 2011);
      expect(spindle.comics, 214);
      expect(spindle.series, 26);
      expect(spindle.events, 5);
    });

    test('T-0067-AC1: every character has 0 to 2 distinct aliases other than '
        'its own name and six stats from 1 to 100', () {
      final universe = CharacterUniverse(42, defaultMockClock);
      final counts = <int, int>{};
      for (final c in universe.byName) {
        counts.update(c.aliases.length, (n) => n + 1, ifAbsent: () => 1);
        expect(c.aliases.toSet(), hasLength(c.aliases.length), reason: c.name);
        for (final alias in c.aliases) {
          expect(alias, startsWith('The '), reason: c.name);
          expect(c.name, isNot(endsWith(alias.substring(4))), reason: c.name);
        }
        expect(c.stats.keys.toList(), statNames, reason: c.name);
        for (final value in c.stats.values) {
          expect(value, inInclusiveRange(1, 100), reason: c.name);
        }
      }
      expect(counts, {0: 503, 1: 496, 2: 501});
    });

    test('T-0067-AC1: stats depend on the seed, aliases too', () {
      final other = CharacterUniverse(7, defaultMockClock).find(100000)!;
      expect(other.stats, {
        'intelligence': 73,
        'strength': 18,
        'speed': 13,
        'durability': 2,
        'energy': 95,
        'combat': 91,
      });
      expect(other.aliases, ['The Mender', 'The Drifter']);
    });

    test('T-0067-AC1: the synthetic cast serves stats and no aliases, as a '
        'function of the index', () async {
      final synthetic = MockBackend(
        domains: [const SyntheticCharactersDomain(3)],
      ).createDio();
      final first = await _get(synthetic, '/v1/characters/100000');
      expect(first['aliases'], isEmpty);
      expect(first['stats'], {
        'intelligence': 1,
        'strength': 14,
        'speed': 27,
        'durability': 40,
        'energy': 53,
        'combat': 66,
      });
      final second = await _get(synthetic, '/v1/characters/100001');
      expect(second['stats'], {
        'intelligence': 8,
        'strength': 21,
        'speed': 34,
        'durability': 47,
        'energy': 60,
        'combat': 73,
      });
    });

    test('T-0018-AC6: names are unique and the cast is 1,500', () {
      final universe = CharacterUniverse(42, defaultMockClock);
      expect(universe.byName, hasLength(characterCount));
      expect({for (final c in universe.byName) c.name}, hasLength(1500));
    });

    test(
      'T-0018-AC6: the seed changes details but not the catalogue of names',
      () {
        final a = CharacterUniverse(42, defaultMockClock);
        final b = CharacterUniverse(7, defaultMockClock);
        expect(
          [for (final c in a.byName) c.name],
          [for (final c in b.byName) c.name],
        );
        expect(
          jsonEncode(a.byName.take(20).map((c) => c.toDetailJson()).toList()),
          isNot(
            jsonEncode(b.byName.take(20).map((c) => c.toDetailJson()).toList()),
          ),
        );
      },
    );

    test(
      'T-0018-AC6: ids and paging values are strict decimal digits',
      () async {
        for (final query in [
          'offset=0x10',
          'offset=%2B5',
          'limit=%2030',
          'limit=1e1',
          'limit=%0930',
        ]) {
          final body = await _get(dio, '/v1/characters?$query');
          expect(body['error'], isNotNull, reason: query);
        }
        for (final id in ['0x186A0', '%2B100000', '%20100000', '100000.0']) {
          final body = await _get(dio, '/v1/characters/$id');
          expect(
            (body['error']! as Map)['code'],
            'character_not_found',
            reason: id,
          );
        }
        expect((await _get(dio, '/v1/characters/100000'))['id'], 100000);
      },
    );

    test(
      'T-0018-AC6: the empty scenario validates like the normal handler',
      () async {
        final backend = _backend()..useScenario('characters.empty');
        final dio = backend.createDio();
        for (final query in [
          'limit=0',
          'limit=101',
          'offset=-1',
          'offset=0x1',
          'orderBy=age',
        ]) {
          final body = await _get(dio, '/v1/characters?$query');
          expect(
            (body['error']! as Map)['code'],
            'invalid_parameter',
            reason: query,
          );
        }
        final ok = await _get(dio, '/v1/characters?offset=5&limit=7');
        expect(
          [ok['total'], ok['offset'], ok['limit'], ok['count']],
          [0, 5, 7, 0],
        );
      },
    );

    test('T-0018-AC6: scenarios empty and server_error', () async {
      final backend = _backend();
      final dio = backend.createDio();
      backend.useScenario('characters.empty');
      final empty = await _get(dio, '/v1/characters');
      expect(empty['total'], 0);
      backend.useScenario('characters.server_error');
      final error = await _get(dio, '/v1/characters');
      expect(error['error'], isNotNull);
      backend.useScenario(null);
      expect((await _get(dio, '/v1/characters'))['total'], 1500);
    });
  });

  group('T-0071-AC3 the team filter', () {
    test('T-0071-AC3: team keeps exactly that team, case-insensitively, and '
        'counts the matches', () async {
      final universe = CharacterUniverse(42, defaultMockClock);
      final expected = [
        for (final c in universe.byName)
          if (c.team == 'Harbor Watch') c,
      ];
      expect(expected, isNotEmpty);
      final page = await _get(
        dio,
        '/v1/characters?team=${Uri.encodeQueryComponent('HARBOR-watch')}'
        '&limit=100',
      );
      expect(page['total'], expected.length);
      expect(
        [for (final c in _results(page)) c['id']],
        [
          for (final c in expected.take(100)) c.id,
        ],
      );
    });

    test('T-0071-AC3: team combines with a name prefix and an order', () async {
      final universe = CharacterUniverse(42, defaultMockClock);
      final expected = [
        for (final c in universe.byName.reversed)
          if (c.team == 'The Quiet Ones' && c.name.startsWith('Spi')) c,
      ];
      expect(expected, isNotEmpty);
      final page = await _get(
        dio,
        '/v1/characters?team=${'the-quiet-ones'}'
        '&nameStartsWith=spi&orderBy=-name&limit=100',
      );
      expect(page['total'], expected.length);
      expect(
        [for (final c in _results(page)) c['name']],
        [
          for (final c in expected) c.name,
        ],
      );
    });

    test('T-0071-AC3: an unknown team matches nothing; an empty one filters '
        'nothing; the synthetic cast has no team', () async {
      final none = await _get(dio, '/v1/characters?team=red');
      expect([none['total'], none['count']], [0, 0]);
      final all = await _get(dio, '/v1/characters?team=');
      expect(all['total'], 1500);
      final synthetic = MockBackend(
        domains: [const SyntheticCharactersDomain(5)],
      ).createDio();
      expect(
        (await _get(synthetic, '/v1/characters?team=harbor-watch'))['total'],
        0,
      );
    });
  });
}
