import 'package:flutter_test/flutter_test.dart';

import '../util/settings_home_env.dart';

/// Usage: the app was asked to sign out {2} times
///
/// `signOut()` was called exactly [count] times in all (0: never).
Future<void> theAppWasAskedToSignOutTimes(
  WidgetTester tester,
  int count,
) async {
  expect(signOutRequests(), count);
}
