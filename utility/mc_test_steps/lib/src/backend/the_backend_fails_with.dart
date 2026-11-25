import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/backend_failure_names.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend fails {'GET /v1/characters?offset=30'} with {'server_error'}
///
/// Every matching request fails (the client's own retries included) until
/// `the backend recovers`. A query in the route narrows the match to requests
/// that carry those parameters.
Future<void> theBackendFailsWith(
  WidgetTester tester,
  String route,
  String kind,
) async => McTestSession.current.backend.fail(route, backendFailureNamed(kind));
