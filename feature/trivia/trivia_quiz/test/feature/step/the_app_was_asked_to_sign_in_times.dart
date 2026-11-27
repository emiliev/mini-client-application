import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the app was asked to sign in {1} times
///
/// `requestSignIn()` was called exactly [count] times in all.
Future<void> theAppWasAskedToSignInTimes(
  WidgetTester tester,
  int count,
) async =>
    expect(navigatorCalls().where((c) => c == 'sign in'), hasLength(count));
