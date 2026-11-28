import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: {'reader@mini-client.test'} signs in elsewhere
///
/// Someone signs in without this screen asking (another screen of the app,
/// a user switch): the real `AuthApi` and session. The screen only hears of
/// it through the session.
Future<void> signsInElsewhere(WidgetTester tester, String email) async {
  await signIn(tester, email);
  await mcSettle(tester);
}
