import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The provider snapshot cases: name -> request path with query.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_comics/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
const Map<String, String> snapshotCases = {
  'list_first_page': '/v1/comics?limit=3',
  'list_offset_40': '/v1/comics?offset=40&limit=2',
  'list_title_spi': '/v1/comics?titleStartsWith=spi&limit=3',
  'list_order_release_desc': '/v1/comics?orderBy=-releaseDate&limit=2',
  'list_by_character': '/v1/comics?characterId=100000&limit=3',
  'detail': '/v1/comics/500000',
  'detail_not_found': '/v1/comics/1',
  'series_detail': '/v1/series/400000',
  'series_not_found': '/v1/series/abc',
  'list_invalid_limit': '/v1/comics?limit=0',
  'list_invalid_character_id': '/v1/comics?characterId=x',
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const ComicsMockDomain()]);

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
