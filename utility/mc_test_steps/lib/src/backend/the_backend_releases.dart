import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend releases {'PUT /v1/me/favourites/comic/501500'}
///
/// Lets the requests `the backend holds` kept waiting, and later ones,
/// through, then lets the screen settle. Fails when nothing holds the route.
Future<void> theBackendReleases(WidgetTester tester, String route) async {
  await McTestSession.current.backend.release(route);
  await mcSettle(tester);
}
