import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: {'collector@mini-client.test'} signs in just before the app sends {'PUT /v1/me/favourites/comic/501500'}
///
/// The race behind P-083: the user switches in the window between the
/// caller's own session check and the auth interceptor, because Dio runs
/// each request interceptor in a new event-loop turn. A hook at the front of
/// the root `Dio` makes that switch the moment the first matching request
/// enters the chain: the session changes in memory (the call a real sign-in
/// ends with), then the request goes on to the auth interceptor. It fires
/// once. Without a pin on the request, that request would leave under the
/// new user's bearer.
///
/// Follow it with `the app finishes writing to storage`: the session saves to
/// a real file (F-0038).
Future<void> signsInJustBeforeTheAppSends(
  WidgetTester tester,
  String email,
  String route,
) async {
  final user = fixtureUsers.firstWhere(
    (u) => u.email == email,
    orElse: () =>
        throw ArgumentError.value(email, 'email', 'Not a fixture user'),
  );
  final session = diContainer<Session>();
  var fired = false;
  diContainer<Dio>().interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final request = RecordedRequest(
          method: options.method,
          path: options.uri.path,
          query: options.uri.queryParameters,
        );
        if (!fired && matchesRequest(request, route)) {
          fired = true;
          session
              .signIn(
                userId: user.id,
                tokens: AuthTokens(
                  accessToken: mintAccessToken(user.id, 1),
                  refreshToken: mintRefreshToken(user.id, 1),
                ),
              )
              .ignore();
        }
        handler.next(options);
      },
    ),
  );
}
