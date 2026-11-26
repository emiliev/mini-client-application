// Contract tests are the one place a feature test reaches `src/` (R7).
import 'dart:convert';

import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/domain/model/comic_dto.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/comic_mapper.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_formatters/mc_formatters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The CONTRACT.md list example's summary fields, with the detail fields the
/// contract table adds, verbatim in shape.
const _contractExample = '''
{
  "id": 500060, "title": "Amber Chronicles #1", "issueNumber": 1,
  "seriesId": 400003, "releaseDate": "2010-01-05",
  "cover": {"path": "mock-asset://characters/003", "variant": "portrait_large"},
  "description": "...",
  "series": {"id": 400003, "title": "Amber Chronicles"},
  "creators": [
    {"id": 300001, "name": "Ada Brook", "role": "writer"},
    {"id": 300002, "name": "Bruno Castell", "role": "cover_artist"}
  ],
  "characterIds": [100001, 100002],
  "characters": [
    {"id": 100001, "name": "Amber Bard", "thumbnail": {"path": "mock-asset://characters/004", "variant": "portrait_medium"}},
    {"id": 100002, "name": "Amber Cipher", "thumbnail": {"path": "mock-asset://characters/005", "variant": "portrait_medium"}}
  ],
  "price": {"amountCents": 399, "currency": "USD"},
  "pageCount": 32,
  "variants": [
    {"label": "Midnight", "cover": {"path": "mock-asset://characters/011", "variant": "portrait_large"}}
  ]
}''';

final Dio _dio = MockBackend(
  domains: [
    const ComicsMockDomain(),
    const CharactersMockDomain(),
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

void main() {
  group('T-0041-AC7 ComicDto against the fixture JSON', () {
    test('T-0041-AC7: the CONTRACT.md shape parses field by field', () {
      final dto = ComicDto.fromJson(_example());

      expect(dto.id, 500060);
      expect(dto.title, 'Amber Chronicles #1');
      expect(dto.issueNumber, 1);
      expect(dto.seriesId, 400003);
      expect(dto.releaseDate, '2010-01-05');
      expect(
        dto.cover,
        const ImageDto(
          path: 'mock-asset://characters/003',
          variant: 'portrait_large',
        ),
      );
      expect(
        dto.series,
        const SeriesRefDto(id: 400003, title: 'Amber Chronicles'),
      );
      expect(
        dto.creators.last,
        const CreditDto(
          id: 300002,
          name: 'Bruno Castell',
          role: 'cover_artist',
        ),
      );
      expect(dto.characterIds, [100001, 100002]);
      expect(
        dto.characters.last,
        const CastMemberDto(
          id: 100002,
          name: 'Amber Cipher',
          thumbnail: ImageDto(
            path: 'mock-asset://characters/005',
            variant: 'portrait_medium',
          ),
        ),
      );
      expect(dto.price, const PriceDto(amountCents: 399, currency: 'USD'));
      expect(dto.pageCount, 32);
      expect(dto.variants.single.label, 'Midnight');
    });

    test('T-0041-AC7: a served comic round-trips byte for byte', () async {
      for (final id in [500000, 501500, 502399]) {
        final body = await _get('/v1/comics/$id');
        // The backend writes canonical JSON (sorted keys); so does the check.
        expect(
          canonicalJson(ComicDto.fromJson(body).toJson()),
          canonicalJson(body),
          reason: 'comic $id',
        );
      }
    });

    test('T-0041-AC7: the mapper keeps what the page shows', () async {
      final record = ComicUniverse(42).findComic(501500)!;
      final comic = ComicDto.fromJson(
        await _get('/v1/comics/501500'),
      ).toDomain();

      expect(comic.id, const ComicId(501500));
      expect(comic.title, record.title);
      expect(comic.issueNumber, record.issueNumber);
      expect(comic.description, record.description);
      expect(comic.cover, record.cover);
      expect(comic.price, Money(record.priceCents, Currency.usd));
      expect(comic.pageCount, record.pageCount);
      expect(comic.releaseDate, record.releaseDate);
      expect(comic.releaseDate.isUtc, isTrue);
      expect(
        [for (final c in comic.creators) (c.id, c.name, c.role.wireName)],
        [
          for (final c in record.creators) (CreatorId(c.id), c.name, c.role),
        ],
      );
    });

    test('T-0041-AC7: every role of the contract maps', () {
      expect(
        [for (final r in CreatorRole.values) r.wireName],
        [
          'writer',
          'penciller',
          'inker',
          'colorist',
          'letterer',
          'cover_artist',
        ],
      );
      for (final role in CreatorRole.values) {
        expect(CreatorRole.fromWire(role.wireName), role);
      }
    });

    test('T-0041-AC7: values outside the contract are FormatExceptions', () {
      ComicDto with_(void Function(Map<String, dynamic> json) change) {
        final json = _example();
        change(json);
        return ComicDto.fromJson(json);
      }

      expect(
        () => with_(
          (j) => j['creators'] = [
            {'id': 1, 'name': 'x', 'role': 'editor'},
          ],
        ).toDomain(),
        throwsFormatException,
      );
      expect(
        () =>
            with_((j) => j['price'] = {'amountCents': 1, 'currency': 'XTS'})
                .toDomain(),
        throwsFormatException,
      );
      expect(
        () =>
            with_((j) => j['cover'] = {'path': 'x', 'variant': 'poster'})
                .toDomain(),
        throwsFormatException,
      );
      for (final day in ['2020-1-12', '2020-02-30', '12.01.2020', '']) {
        expect(
          () => with_((j) => j['releaseDate'] = day).toDomain(),
          throwsFormatException,
          reason: day,
        );
      }
      expect(parseDay('2020-02-29'), DateTime.utc(2020, 2, 29));
    });
  });

  group(
    'T-0041-AC7 the cast summary and FavouriteDto against the fixtures',
    () {
      test('T-0041-AC1: the served cast summary maps to the characters '
          "fixture's cast, with no request per character", () async {
        final characters = CharacterUniverse(42, defaultMockClock);
        final comic = ComicDto.fromJson(
          await _get('/v1/comics/501500'),
        ).toDomain();

        expect(comic.cast, hasLength(2));
        for (final (i, member) in comic.cast.indexed) {
          final record = characters.find(
            ComicUniverse(42).findComic(501500)!.characterIds[i],
          )!;
          expect(member.id, CharacterId(record.id));
          expect(member.name, record.name);
          expect(member.image, record.thumbnail);
        }
      });

      test(
        'T-0041-AC7: the favourite answers parse for every method',
        () async {
          final token = mintAccessToken(fixtureUsers.first.id, 1);
          final options = Options(headers: {'Authorization': 'Bearer $token'});
          const path = '/v1/me/favourites/comic/501500';

          final put = FavouriteDto.fromJson(
            (await _dio.put<Map<String, dynamic>>(
              path,
              options: options,
            )).data!,
          );
          expect(
            put,
            const FavouriteDto(kind: 'comic', id: '501500', favourite: true),
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
        },
      );
    },
  );
}
