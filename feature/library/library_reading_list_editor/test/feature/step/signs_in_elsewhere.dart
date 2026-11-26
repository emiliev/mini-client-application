import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: {'collector@mini-client.test'} signs in elsewhere
///
/// Someone signs in without the editor asking (another screen of the app):
/// the real `AuthApi` and session, inside `runAsync` (F-0038). The editor
/// only hears of it through the session.
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
