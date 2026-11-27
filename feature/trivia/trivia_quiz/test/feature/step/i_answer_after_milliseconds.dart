import 'package:flutter_test/flutter_test.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I answer {'C'} after {5000} milliseconds
///
/// Plays the question on screen: [kind] `C` the correct choice, `W` a wrong
/// one, `N` none (the time runs out), after [milliseconds] of fake time.
/// Ends with the question revealed.
Future<void> iAnswerAfterMilliseconds(
  WidgetTester tester,
  String kind,
  int milliseconds,
) async {
  final round = await currentRound(tester);
  await playQuestion(tester, round, (
    kind: kind,
    elapsedMs: milliseconds,
    hint: false,
  ));
}
