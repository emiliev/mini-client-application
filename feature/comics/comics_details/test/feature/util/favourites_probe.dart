import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'comics_details_env.dart';

/// Talks to the backend's identity domain directly, as [email], with a token
/// of the fixture's shape: a second client that reads or seeds what the
/// backend holds. It bypasses the app's `Dio` and the harness, so it adds no
/// request to what the scenario asserts on.
Future<Response<Object?>> favouritesProbe(
  WidgetTester tester,
  String email,
  String method,
  int comic,
) async {
  final user = fixtureUser(email);
  final dio = McTestSession.current.backend.backend.createDio();
  final response = await tester.runAsync(
    () => dio.request<Object?>(
      '/v1/me/favourites/comic/$comic',
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 9999)}'},
        validateStatus: (_) => true,
      ),
    ),
  );
  return response!;
}
