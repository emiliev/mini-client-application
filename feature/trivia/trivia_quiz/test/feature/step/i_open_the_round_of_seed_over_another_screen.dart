import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// The screen the app shows under the quiz in these scenarios.
const belowKey = ValueKey<String>('trivia.test.below');

/// Usage: I open the round {'all'} {'easy'} of seed {42} over another screen
///
/// Like `I open the round ... of seed ...`, but the flow is pushed over
/// another screen (with no transition, so fake time does not move), as the
/// app pushes `/trivia/play` over `/trivia`: leaving the flow shows it.
Future<void> iOpenTheRoundOfSeedOverAnotherScreen(
  WidgetTester tester,
  String category,
  String difficulty,
  int seed,
) async {
  currentSpec = (category: category, difficulty: difficulty, seed: seed);
  await currentRound(tester);
  await ensureTriviaContainer();
  await initFlow(
    tester,
    () => const Scaffold(key: belowKey, body: Text('Under the quiz')),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  // Not awaited: the route completes when the quiz is left.
  navigator
      .push<void>(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => triviaTestHost(
            triviaFlowUnderTest(
              category: category,
              difficulty: difficulty,
              seed: seed,
            ),
          ),
        ),
      )
      .ignore();
  await landAtOnce(tester);
}
