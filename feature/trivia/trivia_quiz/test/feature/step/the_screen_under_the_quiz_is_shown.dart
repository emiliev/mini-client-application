import 'package:flutter_test/flutter_test.dart';

import 'i_open_the_round_of_seed_over_another_screen.dart';

/// Usage: the screen under the quiz is shown
///
/// The quiz was left: the screen it was pushed over is on top again.
Future<void> theScreenUnderTheQuizIsShown(WidgetTester tester) async {
  await tester.pump();
  expect(find.byKey(belowKey).hitTestable(), findsOneWidget);
  expect(find.text('Quit this round?'), findsNothing);
}
