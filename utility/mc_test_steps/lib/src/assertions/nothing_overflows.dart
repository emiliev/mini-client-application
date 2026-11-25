import 'package:flutter_test/flutter_test.dart';

/// Usage: nothing overflows
///
/// No layout error was reported while the screen was built: a `RenderFlex`
/// overflow, like any other framework error, is caught by the tester and
/// would surface here.
Future<void> nothingOverflows(WidgetTester tester) async {
  final error = tester.takeException();
  expect(error, isNull, reason: 'the screen reported a layout error: $error');
}
