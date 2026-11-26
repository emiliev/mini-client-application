import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// One provider snapshot case: a request, optionally after a sign-in.
typedef SnapshotCase = ({
  String method,
  String path,
  Object? body,
  bool signedIn,
});

SnapshotCase _case(
  String method,
  String path, {
  Object? body,
  bool signedIn = false,
}) => (method: method, path: path, body: body, signedIn: signedIn);

/// The provider snapshot cases, by name.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_identity/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`. A `signedIn` case first signs the reader in on
/// the same backend (not part of the snapshot).
final Map<String, SnapshotCase> snapshotCases = {
  'sign_in': _case(
    'POST',
    '/v1/auth/sign-in',
    body: {'email': 'reader@mini-client.test', 'password': 'marvelous'},
  ),
  'sign_in_wrong_password': _case(
    'POST',
    '/v1/auth/sign-in',
    body: {'email': 'reader@mini-client.test', 'password': 'nope'},
  ),
  'refresh': _case(
    'POST',
    '/v1/auth/refresh',
    body: {'refreshToken': 'mc-refresh-u-100-1'},
  ),
  'refresh_unknown_token': _case(
    'POST',
    '/v1/auth/refresh',
    body: {'refreshToken': 'garbage'},
  ),
  'me': _case('GET', '/v1/me', signedIn: true),
  'me_unauthenticated': _case('GET', '/v1/me'),
  'favourite_get': _case(
    'GET',
    '/v1/me/favourites/character/100000',
    signedIn: true,
  ),
  'favourite_get_missing': _case(
    'GET',
    '/v1/me/favourites/comic/1',
    signedIn: true,
  ),
  'favourite_put': _case('PUT', '/v1/me/favourites/comic/1', signedIn: true),
  'favourite_delete': _case(
    'DELETE',
    '/v1/me/favourites/character/100000',
    signedIn: true,
  ),
  'favourite_invalid_kind': _case(
    'PUT',
    '/v1/me/favourites/pony/1',
    signedIn: true,
  ),
};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const IdentityMockDomain()]);

/// Runs one case and returns `{"request", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(SnapshotCase c) async {
  final dio = snapshotBackend().createDio();
  final headers = <String, Object?>{};
  if (c.signedIn) {
    // Mints token number 1, which `refresh` and `me` rely on being known.
    final tokens = await dio.post<Map<String, Object?>>(
      '/v1/auth/sign-in',
      data: {'email': 'reader@mini-client.test', 'password': 'marvelous'},
    );
    headers['Authorization'] = 'Bearer ${tokens.data!['accessToken']}';
  }
  final response = await dio.request<String>(
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
    'request': '${c.method} ${c.path}',
    'status': response.statusCode,
    'body': text == null || text.isEmpty ? null : jsonDecode(text),
  };
}
