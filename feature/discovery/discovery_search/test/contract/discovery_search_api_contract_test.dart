// Contract tests are the one place a feature test reaches `src/` (R7).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:discovery_search/src/domain/api/discovery_search_api.dart';
import 'package:discovery_search/src/domain/model/character_id.dart';
import 'package:discovery_search/src/domain/model/comic_id.dart';
import 'package:discovery_search/src/domain/model/search_dto.dart';
import 'package:discovery_search/src/domain/model/search_mapper.dart';
import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:discovery_search/src/domain/repository/discovery_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The CONTRACT.md `GET /v1/search` example, verbatim in shape.
const _contractExample = '''
{
  "query": "spi",
  "groups": [
    {
      "type": "character", "total": 152,
      "results": [
        {
          "id": 100480, "type": "character", "title": "Spindle Alchemist",
          "subtitle": "The Lantern Circle",
          "thumbnail": {"path": "mock-asset://characters/014", "variant": "portrait_medium"}
        }
      ]
    },
    {"type": "comic", "total": 400, "results": []}
  ]
}''';

MockBackend _backend({List<MockDomain> domains = const []}) => MockBackend(
  domains: domains.isEmpty ? [const DiscoveryMockDomain()] : domains,
);

final Dio _dio = _backend().createDio();

/// The feature's own API and repository over the backend's `Dio`, the way
/// the flow builds them (relative paths on a base URL ending with `/`).
DiscoverySearchRepository _repository([Dio? dio]) =>
    DiscoverySearchRepository(DiscoverySearchApi(dio ?? _dio));

Future<Map<String, dynamic>> _get(String path) async =>
    (await _dio.get<Map<String, dynamic>>(path)).data!;

Map<String, dynamic> _example() =>
    jsonDecode(_contractExample) as Map<String, dynamic>;

void main() {
  group('T-0046-AC7 SearchResponseDto against the fixture JSON', () {
    test('T-0046-AC7: the CONTRACT.md shape parses field by field', () {
      final dto = SearchResponseDto.fromJson(_example());

      expect(dto.query, 'spi');
      expect([for (final g in dto.groups) g.type], ['character', 'comic']);
      expect(dto.groups.first.total, 152);
      expect(
        dto.groups.first.results.single,
        const SearchResultDto(
          id: 100480,
          type: 'character',
          title: 'Spindle Alchemist',
          subtitle: 'The Lantern Circle',
          thumbnail: SearchImageDto(
            path: 'mock-asset://characters/014',
            variant: 'portrait_medium',
          ),
        ),
      );
      expect(dto.groups.last.total, 400);
      expect(dto.groups.last.results, isEmpty);
    });

    test('T-0046-AC7: served answers round-trip byte for byte', () async {
      for (final path in [
        'v1/search?q=spi',
        'v1/search?q=spindle&limit=20',
        'v1/search?q=Spire%20Warden',
        'v1/search?q=zzzz',
        'v1/search?q=chron&types=comic&limit=5',
        'v1/search?q=ard&types=character&limit=100',
      ]) {
        final body = await _get(path);
        // The backend writes canonical JSON (sorted keys); so does the check.
        expect(
          canonicalJson(SearchResponseDto.fromJson(body).toJson()),
          canonicalJson(body),
          reason: path,
        );
      }
    });

    test('T-0046-AC7: a character without a team has no subtitle, and '
        'round-trips without one', () async {
      final body = await _get('v1/search?q=an&limit=100');
      final results = [
        for (final g in SearchResponseDto.fromJson(body).groups) ...g.results,
      ];
      final noTeam = results.where((r) => r.subtitle == null).toList();
      expect(noTeam, isNotEmpty, reason: 'the fixture has team-less matches');
      expect(noTeam.first.toJson().containsKey('subtitle'), isFalse);
    });

    test(
      'T-0046-AC7: the suggestions answer round-trips byte for byte',
      () async {
        final api = DiscoverySearchApi(_dio);
        final dto = await api.suggestions('spi');

        expect(dto.query, 'spi');
        expect(dto.suggestions, [
          'Spindle Alchemist',
          'Spindle Artisan',
          'Spindle Bard',
          'Spindle Beacon',
          'Spindle Captain',
        ]);
        expect(
          canonicalJson(dto.toJson()),
          canonicalJson(await _get('v1/search/suggestions?q=spi')),
        );
      },
    );
  });

  group('T-0046-AC1 the repository and the mapper', () {
    test('T-0046-AC1: a search maps both groups in the backend order, with '
        'typed ids and the served art', () async {
      final results = (await _repository().search('spi')).getOrElse(
        () => fail('the search failed'),
      );
      final served = SearchResponseDto.fromJson(
        await _get('v1/search?q=spi&limit=$searchPageSize'),
      );

      expect(results.query, 'spi');
      expect(results.isEmpty, isFalse);
      expect(
        [for (final g in results.groups) g.type],
        [
          SearchType.character,
          SearchType.comic,
        ],
      );
      for (final (i, group) in results.groups.indexed) {
        final wire = served.groups[i];
        expect(group.total, wire.total);
        expect(group.hits, hasLength(searchPageSize));
        for (final (j, hit) in group.hits.indexed) {
          final r = wire.results[j];
          expect(hit.title, r.title);
          expect(hit.subtitle, r.subtitle);
          expect(
            hit.image,
            ApiImage(
              path: r.thumbnail.path,
              variant: ImageVariant.fromWire(r.thumbnail.variant),
            ),
          );
          switch (hit) {
            case CharacterHit(:final id):
              expect(group.type, SearchType.character);
              expect(id, CharacterId(r.id));
            case ComicHit(:final id):
              expect(group.type, SearchType.comic);
              expect(id, ComicId(r.id));
          }
        }
      }
      expect(results.groups.first.hits.first.title, 'Spindle Alchemist');
      expect(results.groups.last.hits.first.title, 'Spindle Chronicles #1');
    });

    test(
      'T-0046-AC1: the repository asks for the first page of each group',
      () async {
        final sent = <Uri>[];
        final dio = _backend().createDio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                sent.add(options.uri);
                handler.next(options);
              },
            ),
          );
        await _repository(dio).search('Spire Warden');

        expect(sent, hasLength(1));
        expect(sent.single.path, '/v1/search');
        expect(sent.single.queryParameters, {
          'q': 'Spire Warden',
          'limit': '$searchPageSize',
        });
      },
    );

    test(
      'T-0046-AC2: nothing found is an empty result, not a failure',
      () async {
        final results = (await _repository().search('zzzz')).getOrElse(
          () => fail('the search failed'),
        );

        expect(results.isEmpty, isTrue);
        expect([for (final g in results.groups) g.total], [0, 0]);
      },
    );

    test('T-0046-AC2: failures come back as values', () async {
      final failing = _backend(domains: [const FailingDiscoveryDomain()]);
      final server = await _repository(failing.createDio()).search('spi');
      expect(
        server.fold((_) => null, (f) => f),
        isA<ApiServer>().having((f) => f.status, 'status', 500),
      );

      final tooShort = await _repository().search('s');
      expect(
        tooShort.fold((_) => null, (f) => f),
        isA<ApiClientError>().having((f) => f.status, 'status', 400),
      );
    });

    test('T-0046-AC7: values outside the contract are malformed', () {
      Map<String, dynamic> withResult(Map<String, dynamic> change) {
        final json = _example();
        final groups = json['groups'] as List<dynamic>;
        final results =
            (groups.first as Map<String, dynamic>)['results'] as List<dynamic>;
        (results.first as Map<String, dynamic>).addAll(change);
        return json;
      }

      expect(
        () =>
            SearchResponseDto.fromJson(withResult({'type': 'film'})).toDomain(),
        throwsFormatException,
      );
      expect(
        () => SearchResponseDto.fromJson(
          withResult({'type': 'comic'}),
        ).toDomain(),
        throwsFormatException,
        reason: 'a comic in the character group',
      );
      expect(
        () => SearchResponseDto.fromJson(
          withResult({
            'thumbnail': {
              'path': 'mock-asset://characters/014',
              'variant': 'x',
            },
          }),
        ).toDomain(),
        throwsFormatException,
      );
      final badGroup = _example();
      (badGroup['groups'] as List<dynamic>).last = {
        'type': 'event',
        'total': 0,
        'results': <Object>[],
      };
      expect(
        () => SearchResponseDto.fromJson(badGroup).toDomain(),
        throwsFormatException,
      );
    });

    test('T-0046-AC7: a malformed answer is ApiMalformed', () async {
      final backend =
          MockBackend(
            domains: [const DiscoveryMockDomain()],
          )..addFailure(
            const FailureRule('GET', '/v1/search', FailureKind.malformed()),
          );
      final result = await _repository(backend.createDio()).search('spi');

      expect(result.fold((_) => null, (f) => f), isA<ApiMalformed>());
    });
  });
}
