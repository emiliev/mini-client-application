import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:trivia_quiz/src/di/di_initializer.dart';
import 'package:trivia_quiz/src/di/flow_scope.dart';
import 'package:trivia_quiz/src/domain/model/round_seeds.dart';
import 'package:trivia_quiz/src/domain/model/trivia_analytics.dart';
import 'package:trivia_quiz/src/domain/time/trivia_ticker.dart';
import 'package:trivia_quiz/src/flow/trivia_quiz_flow_state.dart';
import 'package:trivia_quiz/src/l10n/trivia_quiz_l10n.dart';
import 'package:trivia_quiz/src/navigator/trivia_quiz_navigator.dart';
import 'package:trivia_quiz/src/presentation/page/trivia_play_page.dart';
import 'package:trivia_quiz/src/presentation/page/trivia_results_page.dart';
import 'package:trivia_quiz/src/presentation/page/trivia_setup_page.dart';

/// The feature's only entry point (R4): pick a category and a difficulty,
/// play a timed round of ten questions, see the results. Its comics and
/// signing in leave the feature through [navigator].
///
/// The app builds it from a route (`/trivia`, or `/trivia/play?...` with a
/// [category], [difficulty] and [seed], chronicle_wiring) with the
/// navigator implementation from its wiring, a monotonic [clock] and a seed
/// source; tests pass a mock, the fake clock of the test binding and a fixed
/// seed (ADR-0014). Opened at a round, the flow has no setup page, so
/// leaving the round leaves the flow.
///
/// Its three pages are screens: `trivia_setup`, `trivia_play` and
/// `trivia_results`, tracked from inside the flow by
/// `AnalyticsFlowObserver` (ADR-0012).
///
/// Immutable after creation: the flow reads [navigator], [clock] and
/// [nextSeed] once, when its scope opens. A different round builds a new
/// flow (its `FeatureFlow` is keyed by it).
class TriviaQuizFlow extends StatelessWidget {
  const TriviaQuizFlow({
    required this.navigator,
    required this.clock,
    required this.nextSeed,
    this.category,
    this.difficulty,
    this.seed,
    super.key,
  });

  final TriviaQuizNavigator navigator;

  /// Monotonic milliseconds: the countdown's time (ADR-0014).
  final int Function() clock;

  /// A new round seed (0 to 2^31 - 1) when the player starts a round.
  final int Function() nextSeed;

  /// With [difficulty], opens the flow at that round (`/trivia/play`). The
  /// server checks both: an unknown one shows the round's error.
  final String? category;
  final String? difficulty;

  /// The round seed; a new one from [nextSeed] when null (drawn once, when
  /// the round loads).
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final linked = switch ((category, difficulty)) {
      (final c?, final d?) => RoundRequest(
        category: c,
        difficulty: d,
        seed: seed,
      ),
      _ => null,
    };
    return FeatureFlow<TriviaQuizFlowState>(
      key: ValueKey((category, difficulty, seed)),
      flowInitializer: const TriviaQuizDIInitializer(),
      rootImports: triviaQuizRootImports,
      provide: (scope) => scope
        ..registerSingleton<TriviaQuizNavigator>(navigator)
        ..registerSingleton<TriviaTicker>(TriviaTicker(clock))
        ..registerSingleton<RoundSeeds>(RoundSeeds(nextSeed)),
      localizationsDelegates: const [TriviaQuizL10n.delegate],
      observers: [
        AnalyticsFlowObserver(
          (context) => context.di<AnalyticsTracker>(),
          host: (context) => FlowScope.read(context).outerRoute,
        ),
      ],
      // A linked round that is left leaves the flow (to the route below). A
      // pop, not `maybePop`: the play page guards the route against pops it
      // did not ask for (the back swipe), and this one it did ask for.
      onComplete: (_) => _leave(context),
      state: TriviaQuizFlowState(linked: linked != null, round: linked),
      onGeneratePages: (state) => [
        if (!state.linked)
          const McFlowPage(name: triviaSetupScreen, child: TriviaSetupPage()),
        if (state.result != null)
          const McFlowPage(
            name: triviaResultsScreen,
            child: TriviaResultsPage(),
          )
        else if (state.round case final round?)
          McFlowPage(
            name: triviaPlayScreen,
            arguments: round,
            child: TriviaPlayPage(key: ValueKey(round)),
          ),
      ],
    );
  }
}

void _leave(BuildContext context) {
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}
