import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend holds {'PUT /v1/me/favourites/comic/501500'}
///
/// Matching requests wait (no timers) until `the backend releases` the same
/// route, so a step can look at the screen while they are in flight. The
/// scenario fails if a hold is never released.
Future<void> theBackendHolds(WidgetTester tester, String route) async =>
    McTestSession.current.backend.hold(route);
