import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: signing in succeeds as {'reader@mini-client.test'}
///
/// The app's side of `requestSignIn()`: the fixture user signs in through
/// the real `mc_api_auth` and `mc_session` (inside `runAsync`, F-0038), then
/// the pending request answers true. Fails when the feature is not waiting
/// for a sign-in.
Future<void> signingInSucceedsAs(WidgetTester tester, String email) async {
  final pending = pendingSignIns();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  await signIn(tester, email);
  pending.removeAt(0).complete(true);
  await mcSettle(tester);
}
