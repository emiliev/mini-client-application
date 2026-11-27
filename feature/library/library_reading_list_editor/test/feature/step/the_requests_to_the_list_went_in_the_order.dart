import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the requests to the list went in the order
///   | 'route'                |
///   | 'GET /v1/me/lists/l-1' |
///
/// Every request to `/v1/me/lists...`, in the order the app sent them,
/// equals the table's routes.
Future<void> theRequestsToTheListWentInTheOrder(
  WidgetTester tester,
  DataTable table,
) async => expect(
  [
    for (final r in McTestSession.current.backend.requests)
      if (r.path.startsWith('/v1/me/lists')) r.routeKey,
  ],
  [for (final row in table.asMaps()) row['route']],
  reason: 'the requests to the reading list, in order',
);
