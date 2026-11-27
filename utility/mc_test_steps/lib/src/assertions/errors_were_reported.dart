import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: {1} errors were reported
///
/// Monitoring recorded exactly [count] errors (each bloc state that
/// implements `McFailureState` is one, `McBloc` reports it).
Future<void> errorsWereReported(WidgetTester tester, int count) async => expect(
  McTestSession.current.monitoring.errors,
  hasLength(count),
  reason: 'errors reported to monitoring',
);
