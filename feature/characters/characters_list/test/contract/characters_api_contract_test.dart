// Contract tests are the one place a feature test reaches `src/` (R7).
import 'dart:convert';

import 'package:characters_list/src/domain/model/character_dto.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/model/character_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_client/mc_api_client.dart';
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

Future<Map<String, dynamic>> _page(int offset) async {
  final dio = MockBackend(domains: [const CharactersMockDomain()]).createDio();
  final response = await dio.get<Map<String, dynamic>>(
    '/v1/characters',
    queryParameters: {'offset': offset, 'limit': 30},
  );
  return response.data!;
}

void main() {
  group('T-0032-AC6 CharacterDto against the fixture JSON', () {
    test('T-0032-AC6: the CONTRACT.md example parses field by field', () {
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

    test('T-0032-AC6: every served item round-trips byte for byte', () async {
      final body = await _page(30);
      final page = ApiPage<CharacterDto>.fromJson(
        body,
        (json) => CharacterDto.fromJson(json! as Map<String, dynamic>),
      );

      expect(page.results, hasLength(30));
      // The backend writes canonical JSON (sorted keys); so does the check.
      expect(
        canonicalJson([for (final dto in page.results) dto.toJson()]),
        canonicalJson(body['results']),
      );
    });

    test('T-0032-AC6: the mapper keeps id, name and image', () async {
      final record = CharacterUniverse(42, defaultMockClock).byName.first;
      final body = await _page(0);
      final page = ApiPage<CharacterDto>.fromJson(
        body,
        (json) => CharacterDto.fromJson(json! as Map<String, dynamic>),
      ).toDomain();

      expect(page.offset, 0);
      expect(page.limit, 30);
      expect(page.total, characterCount);
      final first = page.results.first;
      expect(first.id, CharacterId(record.id));
      expect(first.name, record.name);
      expect(first.image, record.thumbnail);
      expect(first.image.variant, ImageVariant.portraitMedium);
    });

    test('T-0032-AC6: an unknown variant is a FormatException', () {
      final dto = CharacterDto.fromJson(
        (jsonDecode(_contractExample) as Map<String, dynamic>)
          ..['thumbnail'] = {'path': 'x', 'variant': 'poster'},
      );

      expect(dto.toDomain, throwsFormatException);
    });
  });
}
