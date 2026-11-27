import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// One request of the provider snapshots, run on a fresh backend.
final class SnapshotCase {
  const SnapshotCase({
    this.user,
    this.authorization,
    this.set = 'platform.default',
    this.scenario,
  });

  /// The user whose access token is sent; null sends no bearer.
  final String? user;

  /// A raw `Authorization` header (it wins over [user]).
  final String? authorization;

  /// The fixture set the backend serves.
  final String set;

  /// A scenario switched on over the default domain (then [set] is unused).
  final String? scenario;

  String get method => 'GET';
  String get path => '/v1/flags';
}

/// The provider snapshot cases: name -> request.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_platform/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
final Map<String, SnapshotCase> snapshotCases = {
  'flags_anonymous': const SnapshotCase(),
  'flags_reader': const SnapshotCase(user: 'u-100'),
  'flags_collector': const SnapshotCase(user: 'u-101'),
  'flags_expired_token': SnapshotCase(
    authorization: 'Bearer ${expiredAccessToken('u-100')}',
  ),
  'flags_empty': const SnapshotCase(set: 'platform.empty'),
  'flags_malformed': const SnapshotCase(set: 'platform.flags_malformed'),
  'flags_server_error': const SnapshotCase(set: 'platform.server_error'),
  'flags_empty_scenario': const SnapshotCase(scenario: 'platform.empty'),
  'flags_malformed_scenario': const SnapshotCase(
    scenario: 'platform.flags_malformed',
  ),
  'flags_server_error_scenario': const SnapshotCase(
    scenario: 'platform.server_error',
  ),
};

MockBackend snapshotBackend(SnapshotCase c) {
  if (c.scenario != null) {
    return MockBackend(domains: [const PlatformMockDomain()])
      ..useScenario(c.scenario);
  }
  return MockBackend(domains: [platformFixtureSets[c.set]!()]);
}

/// Runs one case and returns `{"request", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(SnapshotCase c) async {
  final dio = snapshotBackend(c).createDio();
  final header =
      c.authorization ??
      (c.user == null ? null : 'Bearer ${mintAccessToken(c.user!, 1)}');
  final response = await dio.request<String>(
    c.path,
    options: Options(
      method: c.method,
      headers: {if (header != null) 'Authorization': header},
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
