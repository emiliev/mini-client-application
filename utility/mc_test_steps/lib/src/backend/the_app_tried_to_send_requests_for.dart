import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/request_attempts.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the app tried to send {0} requests for {'POST /v1/me/lists'}
///
/// Counts the requests that entered the `Dio` (after `the app records every
/// request it tries to send`), including the ones an interceptor rejected.
Future<void> theAppTriedToSendRequestsFor(
  WidgetTester tester,
  int count,
  String route,
) async {
  final tried = requestsTheAppTriedToSend()
      .where((r) => matchesRequest(r, route))
      .toList();
  expect(tried, hasLength(count), reason: 'tried to send $route: $tried');
}
