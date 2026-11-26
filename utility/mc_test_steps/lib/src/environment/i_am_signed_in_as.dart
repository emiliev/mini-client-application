import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I am signed in as {'reader@mini-client.test'}
///
/// Signs a fixture user (`mc_fixtures_identity` CONTRACT.md) in through the
/// real `AuthApi` and session of the test container, before the flow opens.
/// The scenario must serve the identity routes
/// (`the backend serves {'identity.default'}`). The session saves to a real
/// file, so the call runs inside `runAsync` (F-0038).
Future<void> iAmSignedInAs(WidgetTester tester, String email) async {
  final user = fixtureUsers.firstWhere(
    (u) => u.email == email,
    orElse: () => throw ArgumentError.value(
      email,
      'email',
      'Not a fixture user. Known: ${[for (final u in fixtureUsers) u.email]}',
    ),
  );
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
  final result = await tester.runAsync(
    () => diContainer<AuthApi>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
  expect(diContainer<SessionReader>().userId, user.id);
}
