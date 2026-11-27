import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: {'reader@mini-client.test'} signs in elsewhere
///
/// Someone signs in without this page asking (another screen of the app):
/// the real `AuthApi` and session, inside `runAsync` (the session saves to a
/// real file, F-0038). The page only hears of it through the session.
Future<void> signsInElsewhere(WidgetTester tester, String email) async {
  final user = fixtureUser(email);
  final result = await tester.runAsync(
    () => diContainer<AuthApi>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
  await mcSettle(tester);
}
