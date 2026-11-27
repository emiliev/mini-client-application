import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the text scale is {2}
///
/// The system text size as a factor of the default (1: default, 2: twice
/// as large). Set it before the step that opens the flow; `initFlow` reads
/// it.
Future<void> theTextScaleIs(WidgetTester tester, num scale) async {
  expect(scale, greaterThan(0), reason: 'a text scale is positive');
  McTestSession.current.textScale = scale.toDouble();
}
