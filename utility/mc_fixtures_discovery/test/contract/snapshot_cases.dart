import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The provider snapshot cases: name -> request path with query.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_discovery/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
const Map<String, String> snapshotCases = {
  'search_spi': '/v1/search?q=spi&limit=3',
  'search_exact_character': '/v1/search?q=Spire%20Warden',
  'search_comic_only':
      '/v1/search?q=amber%20chronicles%20%231&types=comic&limit=3',
  'search_word_prefix': '/v1/search?q=chron&types=comic&limit=2',
  'search_substring': '/v1/search?q=ard&types=character&limit=2',
  'search_diacritics': '/v1/search?q=%20SP%C3%8FRE%20&limit=1',
  'search_no_match': '/v1/search?q=zzzz',
  'suggestions_spi': '/v1/search/suggestions?q=spi',
  'suggestions_none': '/v1/search/suggestions?q=zzzz',
  'search_too_short': '/v1/search?q=s',
  'search_missing_query': '/v1/search',
  'search_invalid_types': '/v1/search?q=spi&types=character,film',
  'search_invalid_limit': '/v1/search?q=spi&limit=0',
  'suggestions_too_short': '/v1/search/suggestions?q=%20s%20',
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const DiscoveryMockDomain()]);

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
