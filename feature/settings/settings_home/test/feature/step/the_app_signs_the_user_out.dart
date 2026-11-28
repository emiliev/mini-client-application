import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: the app signs the user out
///
/// The app's side of `signOut()`: the real `AuthApi.signOut` (inside
/// `runAsync`: the session clears a real file, F-0038), then the pending
/// request completes. Fails when the feature is not waiting for a sign-out.
Future<void> theAppSignsTheUserOut(WidgetTester tester) async {
  final pending = pendingSignOuts();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign out');
  await tester.runAsync(() => diContainer<AuthApi>().signOut());
  pending.removeAt(0).complete();
  await mcSettle(tester);
}
