import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I tap the hint as the app becomes inactive
///
/// The app leaves the foreground (`inactive`) and, in the same frame, before
/// the page could redraw the hint as disabled, the hint is tapped: the
/// tap's event reaches the bloc after the pause, so the bloc itself must
/// refuse it. The tear-down of `the app lifecycle becomes` is not needed:
/// the scenario returns to `resumed`.
Future<void> iTapTheHintAsTheAppBecomesInactive(WidgetTester tester) async {
  expect(
    find.byKey(playHintKey),
    findsOneWidget,
    reason: 'the hint is offered',
  );
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.tap(find.byKey(playHintKey));
  await tester.pump();
}
