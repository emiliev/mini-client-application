import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I ask to quit the round
///
/// Taps the play page's close button, then draws the dialog's entrance
/// (the countdown is already paused, so its time does not count).
Future<void> iAskToQuitTheRound(WidgetTester tester) async {
  await tester.tap(find.byKey(playQuitKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
