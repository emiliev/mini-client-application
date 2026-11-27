import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/auth_signin_env.dart';

/// Usage: I let the sign-in request through
///
/// Releases the held `POST /v1/auth/sign-in` (`the backend holds ...`), then
/// lets the sign-in finish, including the session's real file save.
Future<void> iLetTheSigninRequestThrough(WidgetTester tester) async {
  await McTestSession.current.backend.release('POST /v1/auth/sign-in');
  await settleSignIn(tester);
}
