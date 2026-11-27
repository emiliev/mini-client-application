import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: signing in is cancelled
///
/// The user backs out of the app's sign-in: the pending request answers
/// false and nobody signs in.
Future<void> signingInIsCancelled(WidgetTester tester) async {
  final pending = pendingSignIns();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  pending.removeAt(0).complete(false);
  await mcSettle(tester);
}
