import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the screens tracked are {'home, characters_list, home'}
///
/// The screens that reached the analytics sink are exactly these, in this
/// order, each once as listed: a missing, extra, repeated or reordered screen
/// fails. `{''}` means no screen at all. Use it where order and repeats
/// matter (going back tracks the page below again); `the screen {name} was
/// tracked` only checks that a screen is somewhere in the list.
Future<void> theScreensTrackedAre(WidgetTester tester, String names) async {
  await tester.pump();
  final expected = names.trim().isEmpty
      ? <String>[]
      : [for (final n in names.split(',')) n.trim()];
  expect(
    McTestSession.current.analytics.screens,
    expected,
    reason: 'the screens tracked, in order',
  );
}
