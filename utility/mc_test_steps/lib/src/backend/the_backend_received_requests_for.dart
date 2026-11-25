import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {2} requests for {'GET /v1/characters'}
///
/// Exactly [count] requests matched [route] (query parameters in the route
/// narrow the match). Client retries are requests too.
Future<void> theBackendReceivedRequestsFor(
  WidgetTester tester,
  int count,
  String route,
) async {
  final requests = McTestSession.current.backend.requests;
  expect(
    requests.where((r) => matchesRequest(r, route)),
    hasLength(count),
    reason: 'requests matching "$route"; received: $requests',
  );
}
