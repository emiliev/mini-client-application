import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/auth_signin_env.dart';

/// Usage: I open the sign-in form
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator passed in the constructor and a result recorder as
/// `onComplete` [tide-nav §3.1].
Future<void> iOpenTheSigninForm(WidgetTester tester) async {
  await ensureSignInContainer();
  await initFlow(tester, () => signInFlowUnderTest());
  await mcSettle(tester);
}
