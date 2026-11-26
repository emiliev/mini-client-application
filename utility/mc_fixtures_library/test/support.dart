import 'package:dio/dio.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// A backend serving the library domain (the default set).
MockBackend libraryBackend({
  int seed = 42,
  MockDomain domain = const LibraryMockDomain(),
}) => MockBackend(seed: seed, domains: [domain]);

/// A Dio that never throws on a status and returns the raw body text.
Dio plainDio(MockBackend backend) {
  final dio = backend.createDio();
  dio.options.validateStatus = (_) => true;
  dio.options.responseType = ResponseType.plain;
  return dio;
}

/// A Dio that never throws on a status and decodes JSON.
Dio jsonDio(MockBackend backend) =>
    backend.createDio()..options.validateStatus = (_) => true;

/// The bearer header of a valid access token for [userId].
Map<String, String> bearer(String userId, [int n = 1]) => {
  'Authorization': 'Bearer ${mintAccessToken(userId, n)}',
};

const String reader = 'u-100';
const String collector = 'u-101';

/// Comic ids in title order (the first [count]), all known to the backend.
List<int> comicIds(int count) => [
  for (final c in ComicUniverse(42).byTitle.take(count)) c.id,
];

/// A request as `(method, path, body)`: the six routes with valid inputs.
typedef Call = (String method, String path, Object? body);

List<Call> everyRoute(String listId) => [
  ('GET', '/v1/me/lists', null),
  ('GET', '/v1/me/lists/$listId', null),
  (
    'POST',
    '/v1/me/lists',
    {'name': 'N', 'visibility': 'private', 'comicIds': <int>[]},
  ),
  ('PUT', '/v1/me/lists/$listId', {'name': 'N', 'visibility': 'private'}),
  ('PUT', '/v1/me/lists/$listId/items', {'comicIds': <int>[]}),
  ('DELETE', '/v1/me/lists/$listId', null),
];

Future<Response<T>> call<T>(
  Dio dio,
  String method,
  String path, {
  Object? body,
  Map<String, String>? headers,
}) => dio.request<T>(
  path,
  data: body,
  options: Options(method: method, headers: headers),
);
