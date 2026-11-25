import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

void main() {
  group('T-0032-AC1 ApiPage reads the mocked backend page envelope', () {
    late Map<String, dynamic> body;

    setUp(() async {
      final dio = createApiDio(
        adapter: MockBackend(domains: [const CharactersMockDomain()]).adapter,
      );
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/characters',
        queryParameters: {'offset': 30, 'limit': 30},
      );
      body = response.data!;
    });

    test('T-0032-AC1: every envelope field is read', () {
      final page = ApiPage<String>.fromJson(
        body,
        (json) => (json! as Map<String, dynamic>)['name'] as String,
      );

      expect(page.offset, 30);
      expect(page.limit, 30);
      expect(page.total, characterCount);
      expect(page.count, 30);
      expect(page.results, hasLength(30));
      expect(page.results.first, isA<String>());
    });

    test('T-0032-AC1: toJson writes the same envelope keys', () {
      final page = ApiPage<Object?>.fromJson(body, (json) => json);

      final json = page.toJson((item) => item);

      expect(json.keys.toSet(), body.keys.toSet());
      expect(json['results'], body['results']);
    });
  });
}
