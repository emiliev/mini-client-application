import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';

import '../util/comics_details_env.dart';

/// Usage: the app sent {'PUT /v1/me/favourites/comic/501500'} with the bearer of {'reader@mini-client.test'}
///
/// Every request with that method and path left the app (after every
/// interceptor) with `Authorization: Bearer <token>`, where the token is the
/// session's own and has the fixture shape of that user's access tokens.
Future<void> theAppSentWithTheBearerOf(
  WidgetTester tester,
  String route,
  String email,
) async {
  final [method, path] = route.split(' ');
  final user = fixtureUser(email);
  final sent = [
    for (final r in sentRequests())
      if (r.method == method && r.path == path) r,
  ];
  expect(sent, isNotEmpty, reason: 'the app sent $route');
  final token = diContainer<SessionReader>().accessToken;
  // CONTRACT.md: `mc-access-<userId>-<n>`; `mintAccessToken` is that shape.
  final shape = RegExp(
    '^${RegExp.escape(mintAccessToken(user.id, 1)).replaceFirst(RegExp(r'1$'), r'\d+')}\$',
  );
  expect(token, matches(shape), reason: "$email's access token");
  for (final r in sent) {
    expect(r.authorization, 'Bearer $token', reason: '$route carries $email');
  }
}
