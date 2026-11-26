import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: no error was reported
///
/// Monitoring recorded no error: no bloc entered a failure state (`McBloc`
/// reports each one) and no handler threw.
Future<void> noErrorWasReported(WidgetTester tester) async => expect(
  McTestSession.current.monitoring.errors,
  isEmpty,
  reason: 'errors reported to monitoring',
);
