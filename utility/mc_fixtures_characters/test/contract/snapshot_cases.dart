import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The provider snapshot cases: name -> request path with query.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_characters/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
const Map<String, String> snapshotCases = {
  'list_first_page': '/v1/characters?limit=3',
  'list_offset_30': '/v1/characters?offset=30&limit=2',
  'list_search_spi': '/v1/characters?nameStartsWith=spi&limit=3',
  'list_order_desc': '/v1/characters?orderBy=-name&limit=2',
  'detail': '/v1/characters/100000',
  'detail_not_found': '/v1/characters/1',
  'list_invalid_limit': '/v1/characters?limit=0',
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const CharactersMockDomain()]);

/// Runs one case and returns `{"request", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(String path) async {
  final response = await snapshotBackend().createDio().get<String>(
    path,
    options: Options(
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  return {
    'request': 'GET $path',
    'status': response.statusCode,
    'body': jsonDecode(response.data!),
  };
}
