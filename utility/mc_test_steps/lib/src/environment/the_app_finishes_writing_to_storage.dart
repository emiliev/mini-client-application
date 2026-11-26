import 'package:flutter_test/flutter_test.dart';

/// Usage: the app finishes writing to storage
///
/// Lets real file I/O complete, then settles the screen: a few rounds of
/// real time (`runAsync`) and a pump. A `testWidgets` body runs on fake time,
/// so a session the app saves or clears itself (a sign-out after a rejected
/// refresh, F-0038 fact 1) only finishes once real time passes.
Future<void> theAppFinishesWritingToStorage(WidgetTester tester) async {
  for (var round = 0; round < 10; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
