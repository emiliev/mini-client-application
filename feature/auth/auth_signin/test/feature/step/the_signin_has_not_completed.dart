import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: the sign-in has not completed
///
/// The flow has not ended: `onComplete` was never called.
Future<void> theSigninHasNotCompleted(WidgetTester tester) async =>
    expect(signInResults(), isEmpty, reason: 'the flow has not ended');
