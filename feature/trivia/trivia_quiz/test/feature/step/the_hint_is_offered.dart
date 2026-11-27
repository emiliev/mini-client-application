import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the hint is offered
///
/// The hint button is on screen and enabled.
Future<void> theHintIsOffered(WidgetTester tester) async {
  await tester.pump();
  final hint = find.byKey(playHintKey);
  expect(hint, findsOneWidget);
  expect(tester.widget<McButton>(hint).onPressed, isNotNull);
}
