import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/storage_io.dart';

/// Usage: the app finishes writing to storage, never showing {'Could not clear'}
///
/// As `the app finishes writing to storage`, and after every frame on the
/// way the screen must not show [text]: a state that would flash up while
/// the I/O lands, and that the end state alone would not reveal.
Future<void> theAppFinishesWritingToStorageNeverShowing(
  WidgetTester tester,
  String text,
) async {
  void check() => expect(
    find.text(text),
    findsNothing,
    reason: '"$text" showed while storage I/O landed',
  );
  await mcFinishStorageIo(tester, afterEachPump: check);
  await tester.pumpAndSettle();
  check();
}
