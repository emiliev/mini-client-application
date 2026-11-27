// Screen goldens of the flow (plan 05 §1.2), entered through the barrel: the
// three pages (setup, a question being played and revealed, the results) and
// the three painters (the countdown ring, the streak meter and the results
// breakdown) in the 4 themes, plus the reduce-motion countdown. Real Inter
// fonts and the bundled fixture art, on the 402x874 reference surface.
//
//   tool/bazelw run //feature/trivia/trivia_quiz:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/trivia_quiz_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Serves the trivia (signed in as the reader, so the setup shows the best
/// scores and the results are saved) and decodes every placeholder first,
/// so the first frame draws the art (F-0030).
Future<McFixtureAssetBundle> _prepare(WidgetTester tester) async {
  McTestSession.current.backend
    ..useFixtureSet('trivia.default')
    ..useFixtureSet('identity.default');
  await ensureTriviaContainer();
  await signIn(tester, 'reader@mini-client.test');
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  return bundle;
}

Future<void> _openRound(WidgetTester tester) async {
  final bundle = await _prepare(tester);
  currentSpec = (category: 'all', difficulty: 'easy', seed: 42);
  await currentRound(tester);
  await initFlow(
    tester,
    () => triviaTestHost(
      triviaFlowUnderTest(category: 'all', difficulty: 'easy', seed: 42),
      bundle: bundle,
    ),
  );
  await landAtOnce(tester);
}

Future<void> _expectGolden(String name, {Finder? of}) => expectLater(
  of ?? find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  for (final variant in McThemeVariant.values) {
    final v = variant.name;

    mcTestWidgets('T-0064-AC4 golden: the setup in $v', (tester) async {
      McTestSession.current.themeVariant = variant;
      final bundle = await _prepare(tester);
      await initFlow(
        tester,
        () => triviaTestHost(triviaFlowUnderTest(), bundle: bundle),
      );
      await mcSettle(tester);
      expect(find.byKey(setupBestKey('all')), findsOneWidget);
      await _expectGolden('trivia_setup_$v');
    });

    mcTestWidgets('T-0064-AC4 golden: a question 6 s in, a streak of 2, and '
        'the countdown ring and streak meter, in $v', (tester) async {
      McTestSession.current.themeVariant = variant;
      await _openRound(tester);
      final round = await currentRound(tester);
      for (final token in parseAnswerTokens('C0 C0')) {
        await playQuestion(tester, round, token);
        await tapNext(tester);
      }
      await tester.pump(const Duration(milliseconds: 6000));
      await _expectGolden('trivia_play_$v');
      await _expectGolden('trivia_countdown_$v', of: find.byKey(countdownKey));
      await _expectGolden(
        'trivia_streak_$v',
        of: find.byKey(streakMeterKey),
      );
      // The question stays open: a timer the test leaves running is fine,
      // the session's teardown unmounts the flow.
    });

    mcTestWidgets('T-0064-AC4 golden: a wrong answer revealed in $v', (
      tester,
    ) async {
      McTestSession.current.themeVariant = variant;
      await _openRound(tester);
      await playQuestion(
        tester,
        await currentRound(tester),
        (kind: 'W', elapsedMs: 4000, hint: false),
      );
      await tester.pumpAndSettle();
      await _expectGolden('trivia_revealed_$v');
    });

    mcTestWidgets('T-0064-AC4 golden: the results and their breakdown in $v', (
      tester,
    ) async {
      McTestSession.current.themeVariant = variant;
      await _openRound(tester);
      final round = await currentRound(tester);
      for (final token in parseAnswerTokens(
        'C0 C2000 C0 W0 C0 N0 C9000 C0 W0 C0',
      )) {
        await playQuestion(tester, round, token);
        await tapNext(tester);
      }
      await mcSettle(tester);
      expect(find.byKey(resultsBestKey), findsOneWidget);
      await _expectGolden('trivia_results_$v');
      final list = find
          .descendant(
            of: find.byKey(resultsBodyKey),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(breakdownBarsKey),
        200,
        scrollable: list,
      );
      await mcSettle(tester);
      await _expectGolden(
        'trivia_breakdown_$v',
        of: find.byKey(resultsBodyKey),
      );
    });
  }

  mcTestWidgets('T-0064-AC4 golden: with reduce motion the countdown is the '
      'number only', (tester) async {
    reduceMotion = true;
    await _openRound(tester);
    await tester.pump(const Duration(milliseconds: 3000));
    await _expectGolden('trivia_play_reduce_motion');
  });
}
