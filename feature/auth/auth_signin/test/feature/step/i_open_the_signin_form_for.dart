import 'package:auth_signin/auth_signin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/auth_signin_env.dart';

/// Usage: I open the sign-in form for {'favourites'}
///
/// Like `I open the sign-in form`, with the reason code a link or a caller
/// gives (an unknown code is no reason).
Future<void> iOpenTheSigninFormFor(WidgetTester tester, String code) async {
  await ensureSignInContainer();
  await initFlow(
    tester,
    () => signInFlowUnderTest(reason: SignInReason.parse(code)),
  );
  await mcSettle(tester);
}
