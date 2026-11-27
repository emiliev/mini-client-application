import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/store_home_env.dart';

/// Usage: the app was asked to sign in {1} time
///
/// `requestSignIn()` was called exactly [count] times (0: never).
Future<void> theAppWasAskedToSignInTime(WidgetTester tester, int count) async {
  final navigator = storeNavigator();
  if (count == 0) {
    verifyNever(navigator.requestSignIn);
  } else {
    verify(navigator.requestSignIn).called(count);
  }
}
