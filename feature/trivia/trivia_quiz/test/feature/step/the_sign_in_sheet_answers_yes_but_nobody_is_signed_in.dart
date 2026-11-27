import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the sign in sheet answers yes but nobody is signed in
///
/// The pending `requestSignIn()` answers true while the session is still
/// signed out (the session, not the answer, says who is signed in).
Future<void> theSignInSheetAnswersYesButNobodyIsSignedIn(
  WidgetTester tester,
) async {
  final pending = pendingSignIns();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  pending.removeAt(0).complete(true);
  await mcSettle(tester);
}
