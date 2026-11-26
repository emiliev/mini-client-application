import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// One request of the provider snapshots, run on a fresh default backend.
final class SnapshotCase {
  const SnapshotCase(
    this.method,
    this.path, {
    this.body,
    this.user = 'u-100',
    this.showBody = true,
  });

  final String method;
  final String path;
  final Object? body;

  /// The user whose access token is sent; `none` sends no bearer and
  /// `expired` sends u-100's expired one.
  final String user;

  /// False for a body too long to read in a snapshot (it is described).
  final bool showBody;
}

List<int> _known(int count) => [
  for (final c in ComicUniverse(42).byTitle.take(count)) c.id,
];

/// The provider snapshot cases: name -> request.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_library/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
final Map<String, SnapshotCase> snapshotCases = {
  'lists': const SnapshotCase('GET', '/v1/me/lists'),
  'lists_other_user': const SnapshotCase('GET', '/v1/me/lists', user: 'u-101'),
  'get': const SnapshotCase('GET', '/v1/me/lists/l-1'),
  'get_empty_list': const SnapshotCase('GET', '/v1/me/lists/l-3'),
  'get_foreign_list': const SnapshotCase('GET', '/v1/me/lists/l-4'),
  'get_unknown_list': const SnapshotCase('GET', '/v1/me/lists/l-999'),
  'create': SnapshotCase(
    'POST',
    '/v1/me/lists',
    body: {
      'name': ' Origin Stories ',
      'description': 'First issues',
      'visibility': 'public',
      'comicIds': _known(3),
    },
  ),
  'update': const SnapshotCase(
    'PUT',
    '/v1/me/lists/l-1',
    body: {'name': 'Renamed', 'visibility': 'private'},
  ),
  'replace_items': SnapshotCase(
    'PUT',
    '/v1/me/lists/l-2/items',
    body: {'comicIds': _known(3).reversed.toList()},
  ),
  'delete': const SnapshotCase('DELETE', '/v1/me/lists/l-1'),
  'unauthenticated': const SnapshotCase('GET', '/v1/me/lists', user: 'none'),
  'expired_token': const SnapshotCase('GET', '/v1/me/lists', user: 'expired'),
  'invalid_name': const SnapshotCase(
    'POST',
    '/v1/me/lists',
    body: {'name': ' ', 'visibility': 'private', 'comicIds': <int>[]},
  ),
  'invalid_description': SnapshotCase(
    'POST',
    '/v1/me/lists',
    body: {
      'name': 'N',
      'description': 'a' * 281,
      'visibility': 'private',
      'comicIds': <int>[],
    },
    showBody: false,
  ),
  'invalid_visibility': const SnapshotCase(
    'PUT',
    '/v1/me/lists/l-1',
    body: {'name': 'N', 'visibility': 'friends'},
  ),
  'unknown_comic': const SnapshotCase(
    'PUT',
    '/v1/me/lists/l-1/items',
    body: {
      'comicIds': [500000, 12345],
    },
  ),
  'duplicate_comic': const SnapshotCase(
    'PUT',
    '/v1/me/lists/l-1/items',
    body: {
      'comicIds': [500000, 500001, 500000],
    },
  ),
  'too_many_comics': SnapshotCase(
    'PUT',
    '/v1/me/lists/l-1/items',
    body: {'comicIds': _known(101)},
    showBody: false,
  ),
  'invalid_body': const SnapshotCase('POST', '/v1/me/lists', body: [1, 2]),
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const LibraryMockDomain()]);

/// Runs one case and returns `{"request", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(SnapshotCase c) async {
  final headers = switch (c.user) {
    'none' => <String, String>{},
    'expired' => {'Authorization': 'Bearer ${expiredAccessToken('u-100')}'},
    final id => {'Authorization': 'Bearer ${mintAccessToken(id, 1)}'},
  };
  final response = await snapshotBackend().createDio().request<String>(
    c.path,
    data: c.body,
    options: Options(
      method: c.method,
      headers: headers,
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  final text = response.data;
  return {
    'request': '${c.method} ${c.path} as ${c.user}',
    if (c.body != null)
      'requestBody': c.showBody ? c.body : '(omitted: too long to read)',
    'status': response.statusCode,
    'body': text == null || text.isEmpty ? null : jsonDecode(text),
  };
}
