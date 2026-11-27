import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: {'reader@mini-client.test'} signs in elsewhere
///
/// Someone signs in without this screen asking (another screen of the app,
/// a user switch): the real `AuthApi` and session. The screen and the
/// appearance only hear of it through the session.
Future<void> signsInElsewhere(WidgetTester tester, String email) async {
  await signIn(tester, email);
  await mcSettle(tester);
}
