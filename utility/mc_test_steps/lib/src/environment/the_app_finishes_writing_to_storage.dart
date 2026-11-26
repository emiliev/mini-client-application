import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/storage_io.dart';

/// Usage: the app finishes writing to storage
///
/// Lets real file I/O complete, then settles the screen: rounds of real time
/// (`runAsync`) and pumps until the storage directory stops changing
/// (`mcFinishStorageIo`), then `pumpAndSettle`. A `testWidgets` body runs on
/// fake time, so a session the app saves or clears itself (a sign-out after
/// a rejected refresh, F-0038 fact 1), or a queue of saved searches, only
/// finishes once real time passes.
Future<void> theAppFinishesWritingToStorage(WidgetTester tester) async {
  await mcFinishStorageIo(tester);
  await tester.pumpAndSettle();
}
