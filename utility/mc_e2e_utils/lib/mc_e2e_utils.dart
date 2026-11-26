import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Keys of the characters list, which journeys find by (steps find by key,
/// never by feature widget type).
const charactersGridKey = ValueKey<String>('characters_list.grid');
const characterPreviewTitleKey = ValueKey<String>(
  'characters_list.preview.title',
);

/// Runs the app's `main()`, then gives the test binding its error handlers
/// back. `main()` installs the app's own hooks; left in place, a failing
/// `expect` makes the binding assert and `flutter drive` hangs instead of
/// failing (F-0032). The app's errors then fail the test, as e2e wants.
void startApp(void Function() main) {
  final flutterHook = FlutterError.onError;
  final platformHook = PlatformDispatcher.instance.onError;
  main();
  FlutterError.onError = flutterHook;
  PlatformDispatcher.instance.onError = platformHook;
}

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

/// Lets [duration] of real time pass (art decodes and fades in after the
/// names appear).
Future<void> letArtLoad(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 3),
]) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

/// Sends [location] to the running app the way iOS delivers a link to a
/// running app: a `pushRouteInformation` call on `flutter/navigation`
/// (`simctl openurl` shows a prompt no script can answer, F-0020).
Future<void> pushLink(WidgetTester tester, String location) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );
