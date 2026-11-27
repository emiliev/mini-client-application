import 'package:dio/dio.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// A backend serving the platform domain (the default set).
MockBackend platformBackend({
  int seed = 42,
  MockDomain domain = const PlatformMockDomain(),
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

/// `GET /v1/flags` decoded, with the optional [headers].
Future<Response<Map<String, Object?>>> getFlags(
  Dio dio, {
  Map<String, String>? headers,
}) => dio.get<Map<String, Object?>>(
  '/v1/flags',
  options: Options(headers: headers),
);
