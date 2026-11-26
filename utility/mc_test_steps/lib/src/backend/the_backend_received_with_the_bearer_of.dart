import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {'PUT /v1/me/favourites/comic/501500'} with the bearer of {'reader@mini-client.test'}
///
/// At least one request matched the route, and every one of them reached
/// the backend with `Authorization: Bearer <token>`, where the token is the
/// session's current one and has the shape of that fixture user's access
/// tokens (`mc-access-<userId>-<n>`, `mc_fixtures_identity` CONTRACT.md).
Future<void> theBackendReceivedWithTheBearerOf(
  WidgetTester tester,
  String route,
  String email,
) async {
  final user = fixtureUsers.firstWhere(
    (u) => u.email == email,
    orElse: () =>
        throw ArgumentError.value(email, 'email', 'Not a fixture user'),
  );
  final matching = [
    for (final r in McTestSession.current.backend.requests)
      if (matchesRequest(r, route)) r,
  ];
  expect(matching, isNotEmpty, reason: 'no request matched "$route"');
  final token = diContainer<SessionReader>().accessToken;
  final prefix = mintAccessToken(user.id, 1).replaceFirst(RegExp(r'1$'), '');
  expect(
    token,
    matches(RegExp('^${RegExp.escape(prefix)}\\d+\$')),
    reason: "the session holds $email's access token",
  );
  for (final r in matching) {
    expect(
      r.headers['Authorization'],
      'Bearer $token',
      reason: '$r carries the bearer of $email',
    );
  }
}
