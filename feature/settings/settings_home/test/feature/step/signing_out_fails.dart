import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: signing out fails
///
/// The app's `signOut()` throws: the pending request completes with an
/// error, and the session is untouched.
Future<void> signingOutFails(WidgetTester tester) async {
  final pending = pendingSignOuts();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign out');
  pending.removeAt(0).completeError(StateError('the sign-out broke'));
  await mcSettle(tester);
}
