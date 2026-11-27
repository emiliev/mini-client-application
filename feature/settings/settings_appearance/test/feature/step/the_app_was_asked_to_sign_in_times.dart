import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the app was asked to sign in {2} times
///
/// `requestSignIn()` was called exactly [count] times in all.
Future<void> theAppWasAskedToSignInTimes(
  WidgetTester tester,
  int count,
) async {
  expect(signInRequests(), count);
}
