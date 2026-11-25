import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend recovers
///
/// Ends every failure injected with `the backend fails ...` and the active
/// scenario (`McBackendHarness.recover`): later requests get the normal
/// answer, and an unrouted one is reported again. Routes, the backend's
/// store and the recorded requests stay.
Future<void> theBackendRecovers(WidgetTester tester) async =>
    McTestSession.current.backend.recover();
