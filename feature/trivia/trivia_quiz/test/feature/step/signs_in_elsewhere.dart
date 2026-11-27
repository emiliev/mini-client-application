import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: {'collector@mini-client.test'} signs in elsewhere
///
/// Someone signs in without the quiz asking (another screen of the app).
Future<void> signsInElsewhere(WidgetTester tester, String email) async {
  await signIn(tester, email);
  await mcSettle(tester);
}
