import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: the app finishes waiting for the server
///
/// The pending `signOut()` the feature asked for completes (the server
/// answered, or the app gave up waiting).
Future<void> theAppFinishesWaitingForTheServer(WidgetTester tester) async {
  final pending = pendingSignOuts();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign out');
  pending.removeAt(0).complete();
  await mcSettle(tester);
}
