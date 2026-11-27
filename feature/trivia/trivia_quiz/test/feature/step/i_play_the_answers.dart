import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: I play the answers {'C0 W0x9'}
///
/// Plays one token per question, from the question on screen on (the
/// contract's notation: `C<ms>` the correct choice after <ms> of fake time,
/// `W<ms>` a wrong one, `N<ms>` none, `h` the hint first, `xN` repeats),
/// tapping Next after each, so the last one opens the results. Between
/// questions fake time does not move: each answer's elapsed time is exactly
/// its token's.
Future<void> iPlayTheAnswers(WidgetTester tester, String answers) async {
  final round = await currentRound(tester);
  for (final token in parseAnswerTokens(answers)) {
    await playQuestion(tester, round, token);
    await tapNext(tester);
  }
  await mcSettle(tester);
}
