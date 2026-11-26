import 'package:flutter_test/flutter_test.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend answered {'PUT /v1/me/favourites/comic/501500'} with {200}
///
/// At least one request matched the route (method or `*`, and a path that
/// may use `:name` segments), and the backend answered every one of them
/// with [status]. Reads the backend's own traffic log, so a route that needs
/// a bearer answering 200 shows that the bearer was good.
Future<void> theBackendAnsweredWith(
  WidgetTester tester,
  String route,
  int status,
) async {
  final space = route.indexOf(' ');
  expect(space, greaterThan(0), reason: 'route is "<METHOD> <path>"');
  final rule = FailureRule(
    route.substring(0, space).toUpperCase(),
    route.substring(space + 1).trim(),
    const FailureKind.timeout(),
  );
  final traffic = McTestSession.current.backend.backend.recentTraffic;
  final matching = [
    for (final entry in traffic)
      if (rule.matches(MockRequest(method: entry.method, path: entry.path)))
        entry,
  ];
  expect(matching, isNotEmpty, reason: 'no request for "$route": $traffic');
  expect(
    [for (final entry in matching) entry.status],
    everyElement(status),
    reason: 'answers to "$route": $matching',
  );
}
