import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend recovers
///
/// Ends every injected failure and scenario: later requests get the normal
/// answer. The fixture sets' routes and the recorded requests stay.
Future<void> theBackendRecovers(WidgetTester tester) async =>
    McTestSession.current.backend.backend.reset();
