import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend holds the next {'GET /v1/store/deals'}
///
/// Only the next matching request waits until `the backend releases` the
/// same route; later ones are answered at once. So a scenario can keep an
/// older request in flight while a newer one to the same route (a refresh,
/// a Retry) is answered, then release the older one and check that its late
/// answer changes nothing. The scenario fails if the hold is never released.
Future<void> theBackendHoldsTheNext(WidgetTester tester, String route) async =>
    McTestSession.current.backend.holdNext(route);
