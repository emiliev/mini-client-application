import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: the app ends the session and waits for the server
///
/// The app's side of `signOut()` while the server is slow: the real
/// `AuthApi.signOut` ends the session at once (inside `runAsync`: the session
/// clears a real file, F-0038) and then waits for the sign-out request, which
/// the scenario holds. The feature's request stays pending until `the app
/// finishes waiting for the server`.
Future<void> theAppEndsTheSessionAndWaitsForTheServer(
  WidgetTester tester,
) async {
  expect(
    pendingSignOuts(),
    isNotEmpty,
    reason: 'the feature asked to sign out',
  );
  await tester.runAsync(() async {
    // Not awaited: the held request never answers before the scenario says so.
    final call = diContainer<AuthApi>().signOut();
    expect(call, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await mcSettle(tester);
}
