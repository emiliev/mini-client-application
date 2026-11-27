import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _setupBody = ValueKey<String>('trivia_setup.body');
const _start = ValueKey<String>('trivia_setup.start');
const _prompt = ValueKey<String>('trivia_play.prompt');
const _next = ValueKey<String>('trivia_play.next');
const _resultsBody = ValueKey<String>('trivia_results.body');
const _score = ValueKey<String>('trivia_results.score');
const _donut = ValueKey<String>('trivia_results.donut');
const _bars = ValueKey<String>('trivia_results.bars');

ValueKey<String> _choice(String id) => ValueKey('trivia_play.choice.$id');

/// T-0064-AC5 on a simulator, through the real `main()`: home, Trivia, the
/// setup, a full Characters / Hard round (answers tapped, one question left
/// to time out), and the results with their charts. Run through
/// `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0064-AC5 home to the quiz, a full round with a timeout, and '
      'the results with their charts', (tester) async {
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'the home page');
    await tester.scrollUntilVisible(
      find.text('Trivia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shot(binding, tester, '60_home_trivia_entry');

    await tester.tap(find.text('Trivia'));
    await pumpUntil(tester, find.byKey(_setupBody), 'the setup');
    await tester.tap(
      find.byKey(const ValueKey('trivia_setup.category.characters')),
    );
    await tester.tap(
      find.byKey(const ValueKey('trivia_setup.difficulty.hard')),
    );
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '61_setup_characters_hard');

    await tester.tap(find.byKey(_start));
    await pumpUntil(tester, find.byKey(_prompt), 'the first question');
    expect(find.text('Question 1 of 10'), findsOneWidget);
    await shot(binding, tester, '62_question_1');

    // The app's seed is random: the journey taps the first choice shown,
    // whatever it is, so the outcomes vary but every path is drawn.
    for (var q = 1; q <= 10; q++) {
      await pumpUntil(tester, find.byKey(_prompt), 'question $q');
      if (q == 4) {
        // Let this one run out (hard: 10 s).
        await pumpUntil(
          tester,
          find.textContaining("Time's up"),
          'the timeout of question 4',
          timeout: const Duration(seconds: 15),
        );
        await shot(binding, tester, '63_question_4_timed_out');
      } else {
        final ids = ['c1', 'c2', 'c3', 'c4'];
        final first = ids.firstWhere(
          (id) => find.byKey(_choice(id)).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(_choice(first)));
        await tester.pump(const Duration(milliseconds: 300));
        if (q == 2) {
          await shot(binding, tester, '64_question_2_revealed');
        }
      }
      await tester.ensureVisible(find.byKey(_next));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(_next));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pumpUntil(tester, find.byKey(_resultsBody), 'the results');
    expect(find.byKey(_score), findsOneWidget);
    expect(find.byKey(_donut), findsOneWidget);
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '65_results');
    await tester.scrollUntilVisible(
      find.byKey(_bars),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(_resultsBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Timed out'), findsWidgets);
    await shot(binding, tester, '66_results_charts');
  });
}
