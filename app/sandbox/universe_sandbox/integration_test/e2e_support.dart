import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Pumps until [finder] matches, or fails with [what] after [timeout]. Real
/// time passes (the live binding), so animations and the mocked backend's
/// timers run as on a device; `pumpAndSettle` would hang on spinners.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder,
  String what, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out after $timeout waiting for $what');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let the frame that built it, and any entrance animation, finish.
  await tester.pump(const Duration(milliseconds: 600));
}

/// Takes a named screenshot of the running app (to `$SCREENSHOT_DIR`).
Future<void> shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
  await binding.takeScreenshot(name);
}

/// The feature's key (steps find by key, never by type).
const charactersGridKey = ValueKey<String>('characters_list.grid');
