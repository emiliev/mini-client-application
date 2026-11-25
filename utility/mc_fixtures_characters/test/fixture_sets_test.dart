import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

Dio _dio(String set) =>
    MockBackend(domains: [charactersFixtureSets[set]!()]).createDio();

Future<Map<String, Object?>> _get(Dio dio, String path) async {
  final response = await dio.get<Map<String, Object?>>(
    path,
    options: Options(validateStatus: (_) => true),
  );
  return response.data!;
}

List<String> _names(Map<String, Object?> page) => [
  for (final c in (page['results']! as List).cast<Map<String, Object?>>())
    c['name']! as String,
];

void main() {
  test(
    'T-0032-AC1 the fixture sets are characters.default, paged_45, empty',
    () {
      expect(charactersFixtureSets.keys, [
        'characters.default',
        'characters.paged_45',
        'characters.empty',
      ]);
      expect(
        charactersFixtureSets['characters.default']!(),
        isA<CharactersMockDomain>(),
      );
    },
  );

  test(
    'T-0032-AC5 characters.paged_45 pages 45 heroes as 30 then 15',
    () async {
      final dio = _dio('characters.paged_45');

      final first = await _get(dio, '/v1/characters?offset=0&limit=30');
      final second = await _get(dio, '/v1/characters?offset=30&limit=30');

      expect(first['total'], 45);
      expect(_names(first), [
        for (var i = 1; i <= 30; i++) 'Hero ${i.toString().padLeft(2, '0')}',
      ]);
      expect(second['count'], 15);
      expect(_names(second).last, 'Hero 45');
    },
  );

  test('T-0032-AC5 a synthetic hero has bundled art and a detail', () async {
    final dio = _dio('characters.paged_45');

    final page = await _get(dio, '/v1/characters?offset=24&limit=1');
    final hero = (page['results']! as List).single as Map<String, Object?>;
    final detail = await _get(dio, '/v1/characters/${hero['id']}');

    expect(hero['name'], 'Hero 25');
    expect(hero['thumbnail'], {
      'path': 'mock-asset://characters/000',
      'variant': 'portrait_medium',
    });
    expect(detail['name'], 'Hero 25');
    expect(
      (await _get(dio, '/v1/characters/1'))['error'],
      containsPair('code', 'character_not_found'),
    );
  });

  test(
    'T-0032-AC1 characters.empty answers a well-formed empty page',
    () async {
      final page = await _get(_dio('characters.empty'), '/v1/characters');

      expect(page, {
        'offset': 0,
        'limit': 20,
        'total': 0,
        'count': 0,
        'results': <Object?>[],
      });
    },
  );

  test('T-0032-AC1 synthetic sets keep the list validation', () async {
    final page = await _get(
      _dio('characters.paged_45'),
      '/v1/characters?limit=0',
    );

    expect(page['error'], containsPair('code', 'invalid_parameter'));
    expect(const SyntheticCharactersDomain(3).scenarios, isEmpty);
  });
}
