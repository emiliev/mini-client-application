import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _setupBody = ValueKey<String>('trivia_setup.body');
const _prompt = ValueKey<String>('trivia_play.prompt');
const _next = ValueKey<String>('trivia_play.next');
const _resultsBody = ValueKey<String>('trivia_results.body');

/// T-0064-AC5's deep link: `miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42`
/// cold opens exactly that round (each question is the one the app's own
/// mocked backend serves for those values, in order) over the setup over
/// home; after the results, Back walks to the setup and then home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0064-AC5 the cold link to a round plays that exact round, '
      'and Back walks to the setup and then home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42',
    );

    startApp(app.main);
    await pumpUntil(tester, find.byKey(_prompt), 'the linked round');
    expect(find.byKey(_home), findsNothing, reason: 'the link was the start');

    // The round the backend serves for the link's values, read past the
    // feature.
    final response = await diContainer<MockBackend>()
        .createDio()
        .get<Map<String, Object?>>(
          'v1/trivia/rounds',
          queryParameters: {
            'category': 'characters',
            'difficulty': 'easy',
            'seed': '42',
          },
        );
    final questions = (response.data!['questions']! as List)
        .cast<Map<String, Object?>>();
    expect(questions, hasLength(10));
    await letArtLoad(tester, const Duration(seconds: 1));
    await shot(binding, tester, '67_deep_link_round');

    for (var q = 0; q < 10; q++) {
      await pumpUntil(tester, find.byKey(_prompt), 'question ${q + 1}');
      expect(
        tester.widget<Text>(find.byKey(_prompt)).data,
        questions[q]['prompt'],
        reason: 'question ${q + 1} of the linked round',
      );
      final correct = questions[q]['correctChoiceId']! as String;
      await tester.tap(find.byKey(ValueKey('trivia_play.choice.$correct')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Correct!'), findsOneWidget);
      await tester.ensureVisible(find.byKey(_next));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(_next));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await pumpUntil(tester, find.byKey(_resultsBody), 'the results');
    expect(find.text('10 of 10 correct'), findsOneWidget);
    await shot(binding, tester, '68_deep_link_results');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_setupBody), 'the setup, after Back');
    await letArtLoad(tester, const Duration(seconds: 1));
    await shot(binding, tester, '68b_back_from_round_is_setup');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_home), 'home, after Back again');
    await shot(binding, tester, '68c_back_from_setup_is_home');
  });
}
