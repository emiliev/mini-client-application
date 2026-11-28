// Contract tests are the one place a feature test reaches `src/` (R7).
import 'dart:convert';

import 'package:characters_search/src/domain/api/characters_search_api.dart';
import 'package:characters_search/src/domain/model/character_dto.dart';
import 'package:characters_search/src/domain/model/character_facets.dart';
import 'package:characters_search/src/domain/model/character_id.dart';
import 'package:characters_search/src/domain/model/character_mapper.dart';
import 'package:characters_search/src/domain/repository/characters_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The CONTRACT.md example item, verbatim.
const _contractExample = '''
{
  "id": 100480, "name": "Spindle Alchemist", "description": "...",
  "modified": "2023-07-13T00:00:00.000Z",
  "thumbnail": {"path": "mock-asset://characters/014", "variant": "portrait_medium"}
}''';

MockBackend _backend() => MockBackend(domains: [const CharactersMockDomain()]);

CharactersSearchRepository _repository(MockBackend backend) =>
    CharactersSearchRepository(CharactersSearchApi(backend.createDio()));

List<CharacterRecord> _cast() => CharacterUniverse(42, defaultMockClock).byName;

void main() {
  group('T-0071-AC1 CharacterDto against the fixture JSON', () {
    test('T-0071-AC1: the CONTRACT.md example parses field by field', () {
      final dto = CharacterDto.fromJson(
        jsonDecode(_contractExample) as Map<String, dynamic>,
      );

      expect(dto.id, 100480);
      expect(dto.name, 'Spindle Alchemist');
      expect(dto.description, '...');
      expect(dto.modified, DateTime.utc(2023, 7, 13));
      expect(
        dto.thumbnail,
        const ThumbnailDto(
          path: 'mock-asset://characters/014',
          variant: 'portrait_medium',
        ),
      );
    });

    test('T-0071-AC1: every served match round-trips byte for byte', () async {
      final response = await _backend().createDio().get<Map<String, dynamic>>(
        '/v1/characters',
        queryParameters: {'nameStartsWith': 'spi', 'limit': 30},
      );
      final body = response.data!;
      final page = ApiPage<CharacterDto>.fromJson(
        body,
        (json) => CharacterDto.fromJson(json! as Map<String, dynamic>),
      );

      expect(page.results, hasLength(30));
      expect(
        canonicalJson([for (final dto in page.results) dto.toJson()]),
        canonicalJson(body['results']),
      );
    });

    test('T-0071-AC1: an unknown variant is a FormatException', () {
      final dto = CharacterDto.fromJson(
        (jsonDecode(_contractExample) as Map<String, dynamic>)
          ..['thumbnail'] = {'path': 'x', 'variant': 'poster'},
      );

      expect(dto.toDomain, throwsFormatException);
    });
  });

  group('T-0071-AC1 the repository over the fixture backend', () {
    test('T-0071-AC1: a prefix page is the fixture cast, in name order, with '
        'its total', () async {
      final backend = _backend();
      final result = await _repository(backend).fetchPage(
        const CharactersSearchQuery(
          prefix: 'spi',
          facets: CharacterFacets(),
          offset: 0,
          limit: 30,
        ),
      );

      final page = result.getOrNull()!;
      final expected = [
        for (final c in _cast())
          if (c.name.toLowerCase().startsWith('spi')) c,
      ];
      expect(expected, hasLength(152));
      expect(page.total, 152);
      expect(page.offset, 0);
      expect(page.limit, 30);
      expect(
        [for (final c in page.results) c.id],
        [
          for (final c in expected.take(30)) CharacterId(c.id),
        ],
      );
      expect(
        [for (final c in page.results) c.name],
        [
          for (final c in expected.take(30)) c.name,
        ],
      );
      expect(page.results.first.image, expected.first.thumbnail);
      expect(page.results.first.image.variant, ImageVariant.portraitMedium);
    });

    test('T-0071-AC1: the request carries the prefix, the order and the '
        'paging, and no team when none is chosen', () async {
      final backend = _backend();
      final dio = backend.createDio();
      final seen = <Uri>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            seen.add(options.uri);
            handler.next(options);
          },
        ),
      );
      await CharactersSearchRepository(CharactersSearchApi(dio)).fetchPage(
        const CharactersSearchQuery(
          prefix: 'spi',
          facets: CharacterFacets(),
          offset: 30,
          limit: 30,
        ),
      );

      expect(seen, hasLength(1));
      expect(seen.single.queryParameters, {
        'nameStartsWith': 'spi',
        'orderBy': 'name',
        'offset': '30',
        'limit': '30',
      });
    });
  });

  group('T-0071-AC3 the facets against the contract', () {
    test('T-0071-AC3: every sort is an order the backend accepts, and each '
        'sorts as its wire name says', () async {
      final cast = _cast();
      final dio = _backend().createDio();
      for (final sort in CharacterSort.values) {
        final response = await dio.get<Map<String, dynamic>>(
          '/v1/characters',
          queryParameters: {
            'nameStartsWith': 'amber',
            'orderBy': sort.wireName,
            'limit': 100,
          },
        );
        final ids = [
          for (final r in response.data!['results'] as List)
            (r as Map<String, dynamic>)['id'] as int,
        ];
        final amber = [
          for (final c in cast)
            if (c.name.startsWith('Amber')) c,
        ];
        int byId(CharacterRecord a, CharacterRecord b) => a.id.compareTo(b.id);
        amber.sort(switch (sort) {
          CharacterSort.nameAscending => (a, b) => a.name.compareTo(b.name),
          CharacterSort.nameDescending => (a, b) => b.name.compareTo(a.name),
          CharacterSort.newest => (a, b) {
            final c = b.modified.compareTo(a.modified);
            return c != 0 ? c : byId(a, b);
          },
          CharacterSort.oldest => (a, b) {
            final c = a.modified.compareTo(b.modified);
            return c != 0 ? c : byId(a, b);
          },
        });
        expect(ids, [for (final c in amber) c.id], reason: sort.wireName);
      }
      expect(
        [for (final s in CharacterSort.values) s.wireName],
        [
          'name',
          '-name',
          '-modified',
          'modified',
        ],
      );
    });

    test('T-0071-AC3: a team id on the wire is the fixture\'s own', () {
      for (final team in characterTeams) {
        expect(characterTeamId(team), teamIdOf(team), reason: team);
      }
      expect(characterTeamId('Harbor Watch'), 'harbor-watch');
      expect(characterTeamId('The Lantern Circle'), 'the-lantern-circle');
    });

    test('T-0071-AC3: the team chips are exactly the teams of the cast', () {
      expect(characterTeams.toSet(), {for (final c in _cast()) c.team});
      expect(characterTeams, hasLength(8));
    });

    test(
      'T-0071-AC3: a team query keeps only that team, with its total',
      () async {
        final result = await _repository(_backend()).fetchPage(
          const CharactersSearchQuery(
            prefix: 'amber',
            facets: CharacterFacets(team: 'Harbor Watch'),
            offset: 0,
            limit: 30,
          ),
        );

        final expected = [
          for (final c in _cast())
            if (c.name.startsWith('Amber') && c.team == 'Harbor Watch') c,
        ];
        final page = result.getOrNull()!;
        expect(page.total, 8);
        expect(
          [for (final c in page.results) c.id],
          [
            for (final c in expected) CharacterId(c.id),
          ],
        );
      },
    );

    test('T-0071-AC3: facets are equal by value and change one field at a '
        'time', () {
      const base = CharacterFacets();
      expect(base.sort, CharacterSort.nameAscending);
      expect(base.team, isNull);
      expect(base, const CharacterFacets());
      expect(base.hashCode, const CharacterFacets().hashCode);

      final sorted = base.withSort(CharacterSort.newest);
      expect(sorted, const CharacterFacets(sort: CharacterSort.newest));
      expect(sorted, isNot(base));

      final team = sorted.withTeam('Open Road');
      expect(
        team,
        const CharacterFacets(sort: CharacterSort.newest, team: 'Open Road'),
      );
      expect(team.withTeam(null), sorted);
      expect(team.withSort(CharacterSort.nameAscending).team, 'Open Road');
    });
  });

  group('T-0071-AC3 failures stay values', () {
    test(
      'T-0071-AC3: a server error is an ApiFailure, not an exception',
      () async {
        final backend = _backend()..useScenario('characters.server_error');
        final result = await _repository(backend).fetchPage(
          const CharactersSearchQuery(
            prefix: 'spi',
            facets: CharacterFacets(),
            offset: 0,
            limit: 30,
          ),
        );

        expect(result.getOrNull(), isNull);
        result.fold((_) => fail('expected a failure'), (error) {
          expect(error, isA<ApiServer>());
        });
      },
    );
  });
}
