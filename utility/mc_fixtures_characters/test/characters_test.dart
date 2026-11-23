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
        if (byDate == 0) expect(a['id']! as int, lessThan(b['id']! as int));
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
}
