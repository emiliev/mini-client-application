import 'package:flutter_test/flutter_test.dart';

/// Usage: {300} milliseconds pass
///
/// Advances fake time by [milliseconds] (timers due in that time fire, such
/// as a debounce), then draws one frame. It does not settle, so a step can
/// look at the moment just before or just after a timer.
Future<void> millisecondsPass(WidgetTester tester, int milliseconds) async {
  await tester.pump(Duration(milliseconds: milliseconds));
  await tester.pump();
}
