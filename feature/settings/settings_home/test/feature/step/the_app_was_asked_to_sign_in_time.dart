import 'package:flutter_test/flutter_test.dart';

import '../util/settings_home_env.dart';

/// Usage: the app was asked to sign in {1} time
///
/// `requestSignIn()` was called exactly [count] times in all (0: never).
Future<void> theAppWasAskedToSignInTime(WidgetTester tester, int count) async {
  expect(signInRequests(), count);
}
