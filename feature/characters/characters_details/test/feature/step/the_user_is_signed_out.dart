import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_session/mc_session.dart';

/// Usage: the user is signed out
///
/// The app's session holds nobody.
Future<void> theUserIsSignedOut(WidgetTester tester) async {
  final session = diContainer<SessionReader>();
  expect(session.isSignedIn, isFalse);
  expect(session.accessToken, isNull);
}
