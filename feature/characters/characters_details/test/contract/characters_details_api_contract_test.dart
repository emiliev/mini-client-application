// Contract tests are the one place a feature test reaches `src/` (R7).
import 'dart:convert';

import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/domain/model/character_dto.dart';
import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/domain/model/character_mapper.dart';
import 'package:characters_details/src/domain/model/comic_id.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The CONTRACT.md detail example: every field of `GET /v1/characters/:id`,
/// verbatim in shape.
const _contractExample = '''
{
  "id": 100001, "name": "Spirit Warden",
  "description": "Spirit Warden was a night-shift tram engineer.",
  "modified": "2023-07-13T00:00:00.000Z",
  "thumbnail": {"path": "mock-asset://characters/014", "variant": "portrait_medium"},
  "powers": ["Magnetic pull", "Phase walking", "Time stutter"],
  "team": "The Quiet Ones",
  "origin": "a night-shift tram engineer",
  "firstAppearanceYear": 1989,
  "appearances": {"comics": 214, "series": 26, "events": 5},
  "aliases": ["The Falconer", "The Smith"],
  "stats": {"combat": 28, "durability": 29, "energy": 79, "intelligence": 58, "speed": 89, "strength": 94}
}''';

final Dio _dio = MockBackend(
  domains: [
    const CharactersMockDomain(),
    const ComicsMockDomain(),
    const IdentityMockDomain(),
  ],
).createDio();

Future<Map<String, dynamic>> _get(String path, {String? bearer}) async =>
    (await _dio.get<Map<String, dynamic>>(
      path,
      options: Options(
        headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'},
      ),
    )).data!;

Map<String, dynamic> _example() =>
    jsonDecode(_contractExample) as Map<String, dynamic>;

CharacterDto _with(void Function(Map<String, dynamic> json) change) {
  final json = _example();
  change(json);
  return CharacterDto.fromJson(json);
}

void main() {
  group('T-0067-AC1 CharacterDto against the fixture JSON', () {
    test('T-0067-AC1: the CONTRACT.md shape parses field by field', () {
      final dto = CharacterDto.fromJson(_example());

      expect(dto.id, 100001);
      expect(dto.name, 'Spirit Warden');
      expect(dto.description, 'Spirit Warden was a night-shift tram engineer.');
      expect(dto.modified, '2023-07-13T00:00:00.000Z');
      expect(
        dto.thumbnail,
        const ImageDto(
          path: 'mock-asset://characters/014',
          variant: 'portrait_medium',
        ),
      );
      expect(dto.powers, ['Magnetic pull', 'Phase walking', 'Time stutter']);
      expect(dto.team, 'The Quiet Ones');
      expect(dto.origin, 'a night-shift tram engineer');
      expect(dto.firstAppearanceYear, 1989);
      expect(
        dto.appearances,
        const AppearancesDto(comics: 214, series: 26, events: 5),
      );
      expect(dto.aliases, ['The Falconer', 'The Smith']);
      expect(dto.stats, {
        'combat': 28,
        'durability': 29,
        'energy': 79,
        'intelligence': 58,
        'speed': 89,
        'strength': 94,
      });
    });

    test('T-0067-AC1: a served character round-trips byte for byte', () async {
      for (final id in [100000, 100001, 101187, 101499]) {
        final body = await _get('/v1/characters/$id');
        // The backend writes canonical JSON (sorted keys); so does the check.
        expect(
          canonicalJson(CharacterDto.fromJson(body).toJson()),
          canonicalJson(body),
          reason: 'character $id',
        );
      }
    });

    test('T-0067-AC1: the mapper keeps what the page shows', () async {
      final record = CharacterUniverse(42, defaultMockClock).find(100001)!;
      final character = CharacterDto.fromJson(
        await _get('/v1/characters/100001'),
      ).toDomain();

      expect(character.id, const CharacterId(100001));
      expect(character.name, record.name);
      expect(character.aliases, record.aliases);
      expect(character.bio, record.description);
      expect(character.portrait, record.thumbnail);
      expect(character.origin, record.origin);
      expect(character.team, record.team);
      expect(character.firstAppearanceYear, record.firstAppearanceYear);
      expect(character.powers, record.powers);
    });
  });

  group('T-0067-AC1 the stats mapping (pure logic)', () {
    test('T-0067-AC1: the stats come in the order of StatKind, whatever the '
        "wire's key order", () {
      final character = _with((j) {
        j['stats'] = {
          'strength': 94,
          'combat': 28,
          'speed': 89,
          'intelligence': 58,
          'energy': 79,
          'durability': 29,
        };
      }).toDomain();

      expect(
        [for (final s in character.stats) (s.kind.wireName, s.value)],
        [
          ('intelligence', 58),
          ('strength', 94),
          ('speed', 89),
          ('durability', 29),
          ('energy', 79),
          ('combat', 28),
        ],
      );
    });

    test('T-0067-AC1: a stat of 1 and a stat of 100 are valid', () {
      final character = _with((j) {
        j['stats'] = {
          ...(j['stats'] as Map<String, dynamic>),
          'combat': 1,
          'energy': 100,
        };
      }).toDomain();

      expect(
        character.stats.last,
        const CharacterStat(kind: StatKind.combat, value: 1),
      );
      expect(
        character.stats[4],
        const CharacterStat(kind: StatKind.energy, value: 100),
      );
    });

    test('T-0067-AC1: a missing, zero or too large stat is a '
        'FormatException (ApiMalformed on the wire)', () {
      expect(
        () => _with((j) {
          (j['stats'] as Map<String, dynamic>).remove('speed');
        }).toDomain(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Missing stat "speed"',
          ),
        ),
      );
      for (final bad in [0, 101, -5]) {
        expect(
          () => _with((j) {
            (j['stats'] as Map<String, dynamic>)['speed'] = bad;
          }).toDomain(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Stat "speed" out of range',
            ),
          ),
          reason: 'speed $bad',
        );
      }
    });

    test('T-0067-AC1: an unknown image variant is a FormatException', () {
      expect(
        () => _with(
          (j) => j['thumbnail'] = {'path': 'x', 'variant': 'poster'},
        ).toDomain(),
        throwsFormatException,
      );
    });

    test('T-0067-AC1: a character with no aliases and no team maps', () {
      final character = _with((j) {
        j['aliases'] = <String>[];
        j['team'] = '';
      }).toDomain();

      expect(character.aliases, isEmpty);
      expect(character.team, isEmpty);
    });
  });

  group('T-0067-AC1 the comics page and FavouriteDto against the fixtures', () {
    test('T-0067-AC1: the comics of a character map in title order, as the '
        "comics fixture's reverse lookup lists them", () async {
      final universe = ComicUniverse(42);
      final page = ComicsPageDto.fromJson(
        await _get('/v1/comics?characterId=100001&limit=20'),
      );
      final comics = [for (final c in page.results) c.toDomain()];

      final expected = universe.comicsOfCharacter(100001);
      expect(page.total, 6);
      expect(page.count, 6);
      expect(
        [for (final c in comics) (c.id, c.title, c.cover)],
        [for (final c in expected) (ComicId(c.id), c.title, c.cover)],
      );
      expect(comics.first.title, 'Ember Chronicles #19');
      expect(comics.last.title, 'Sparrow Reckoning #16');
    });

    test('T-0067-AC1: a character nobody features has an empty page', () async {
      final page = ComicsPageDto.fromJson(
        await _get('/v1/comics?characterId=101187&limit=20'),
      );

      expect(page.total, 0);
      expect(page.results, isEmpty);
    });

    test('T-0067-AC3: the favourite answers parse for every method', () async {
      final token = mintAccessToken(fixtureUsers.first.id, 1);
      final options = Options(headers: {'Authorization': 'Bearer $token'});
      const path = '/v1/me/favourites/character/100001';

      final put = FavouriteDto.fromJson(
        (await _dio.put<Map<String, dynamic>>(path, options: options)).data!,
      );
      expect(
        put,
        const FavouriteDto(kind: 'character', id: '100001', favourite: true),
      );
      final get = FavouriteDto.fromJson(await _get(path, bearer: token));
      expect(get.favourite, isTrue);
      final delete = FavouriteDto.fromJson(
        (await _dio.delete<Map<String, dynamic>>(
          path,
          options: options,
        )).data!,
      );
      expect(delete.favourite, isFalse);
      expect(
        () => _get(path, bearer: token),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            404,
          ),
        ),
        reason: 'not a favourite is a 404',
      );
    });
  });
}
