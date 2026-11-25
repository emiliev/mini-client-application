import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {'GET /v1/characters?offset=0&limit=30'}
///
/// At least one request matched: same method and path, and every query
/// parameter in the route with that value (others may be present).
Future<void> theBackendReceived(WidgetTester tester, String route) async {
  final requests = McTestSession.current.backend.requests;
  expect(
    requests.where((r) => matchesRequest(r, route)),
    isNotEmpty,
    reason: 'no request matched "$route"; received: $requests',
  );
}
