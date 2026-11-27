import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';

/// Usage: the session belongs to {'collector@mini-client.test'}
///
/// The app's session is that fixture user's right now. A race scenario ends
/// with it, so a switch that never happened cannot pass for one that was
/// survived.
Future<void> theSessionBelongsTo(WidgetTester tester, String email) async {
  final user = fixtureUsers.firstWhere(
    (u) => u.email == email,
    orElse: () =>
        throw ArgumentError.value(email, 'email', 'Not a fixture user'),
  );
  expect(
    diContainer<SessionReader>().userId,
    user.id,
    reason: 'the session belongs to $email',
  );
}
