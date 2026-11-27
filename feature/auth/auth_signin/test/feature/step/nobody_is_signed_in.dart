import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_session/mc_session.dart';

/// Usage: nobody is signed in
///
/// The app's session is signed out right now.
Future<void> nobodyIsSignedIn(WidgetTester tester) async => expect(
  diContainer<SessionReader>().isSignedIn,
  isFalse,
  reason: 'nobody is signed in',
);
