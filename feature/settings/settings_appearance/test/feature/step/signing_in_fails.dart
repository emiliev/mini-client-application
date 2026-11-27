import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: signing in fails
///
/// The app's `requestSignIn()` throws (a broken sign-in): the pending
/// request completes with an error, and nobody signs in.
Future<void> signingInFails(WidgetTester tester) async {
  final pending = pendingSignIns();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  pending.removeAt(0).completeError(StateError('the sign-in broke'));
  await mcSettle(tester);
}
