import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {'POST /v1/me/lists'} with a token of {'reader@mini-client.test'}
///
/// At least one request matched the route, and every one of them carried an
/// access token of that fixture user (`Bearer mc-access-<userId>-<n>`,
/// `mc_fixtures_identity` CONTRACT.md), whoever is signed in now. For
/// scenarios where the session changes after a request left: the request
/// went out for the user it was meant for. While the session is unchanged,
/// `the backend received {route} with the bearer of {user}` is stricter.
Future<void> theBackendReceivedWithATokenOf(
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
  final prefix = mintAccessToken(user.id, 1).replaceFirst(RegExp(r'1$'), '');
  final shape = RegExp('^Bearer ${RegExp.escape(prefix)}\\d+\$');
  for (final r in matching) {
    expect(
      r.headers['Authorization'],
      matches(shape),
      reason: '$r carries an access token of $email',
    );
  }
}
