import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: the app asks who is signed in and is answered {200}
///
/// A signed-in request through the app's own `Dio` (`GET /v1/me`, with its
/// auth interceptor, so an expired access token is refreshed on the way)
/// gets that status.
Future<void> theAppAsksWhoIsSignedInAndIsAnswered(
  WidgetTester tester,
  int status,
) async => expect(await askWhoIsSignedIn(tester), status);
