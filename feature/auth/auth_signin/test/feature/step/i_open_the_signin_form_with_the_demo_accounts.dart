import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/auth_signin_env.dart';

/// Usage: I open the sign-in form with the demo accounts
///
/// Like `I open the sign-in form`, with the fixture users offered as demo
/// accounts, as the app does.
Future<void> iOpenTheSigninFormWithTheDemoAccounts(WidgetTester tester) async {
  await ensureSignInContainer();
  await initFlow(tester, () => signInFlowUnderTest(accounts: demoAccounts()));
  await mcSettle(tester);
}
