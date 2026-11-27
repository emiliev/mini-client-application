// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). Also the visit rules the BDD scenarios cannot
// reach through a single flow: a page built under another screen, a round
// covered by another screen, the flag read once per round, and the seed a
// linked round draws.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

import 'feature/util/trivia_quiz_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  void serveTrivia() =>
      McTestSession.current.backend.useFixtureSet('trivia.default');

  int requests(String method, String path) => McTestSession
      .current
      .backend
      .requests
      .where((r) => r.method == method && r.path == path)
      .length;

  Future<void> openRound(WidgetTester tester, {int? seed = 42}) async {
    currentSpec = (category: 'all', difficulty: 'easy', seed: seed ?? 42);
    await currentRound(tester);
    await ensureTriviaContainer();
    await initFlow(
      tester,
      () => triviaTestHost(
        triviaFlowUnderTest(category: 'all', difficulty: 'easy', seed: seed),
      ),
    );
    await landAtOnce(tester);
  }

  mcTestWidgets("T-0064-AC7 the flow's container resolves every "
      'registration', (tester) async {
    serveTrivia();
    await openRound(tester);
    final round = await currentRound(tester);
    for (final token in parseAnswerTokens('W0x10')) {
      await playQuestion(tester, round, token);
      await tapNext(tester);
    }
    await mcSettle(tester);
    // The results bloc needs a finished round in the flow state, so resolve
    // from the results page: navigator, ticker, seeds, API, repository and
    // the three blocs.
    final page = tester.element(find.byKey(resultsBodyKey));
    await page.debugResolveAll();
    await mcSettle(tester);
  });

  for (final missing in [
    'AnalyticsTracker',
    'Dio',
    'FeatureFlagsReader',
    'Monitoring',
    'SessionReader',
  ]) {
    mcTestWidgets('T-0064-AC7 a root without $missing fails naming it', (
      tester,
    ) async {
      final session = McTestSession.current;
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          if (missing != 'Dio') {
            getIt.registerSingleton<Dio>(session.backend.backend.createDio());
          }
          if (missing != 'Monitoring') {
            getIt.registerSingleton<Monitoring>(session.monitoring);
          }
          if (missing != 'SessionReader') {
            getIt.registerSingleton<SessionReader>(_NobodySignedIn());
          }
          if (missing != 'FeatureFlagsReader') {
            getIt.registerSingleton<FeatureFlagsReader>(session.flags);
          }
          if (missing != 'AnalyticsTracker') {
            getIt.registerSingleton<AnalyticsTracker>(_NoTracker());
          }
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: triviaTestHost(triviaFlowUnderTest()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<$missing>'));
      expect(find.byKey(setupBodyKey), findsNothing);
    });
  }

  mcTestWidgets('T-0064-AC7 the setup and the results use McAppBar with '
      'McFlowBackButton; the round has its own close button', (tester) async {
    serveTrivia();
    await ensureTriviaContainer();
    await initFlow(tester, () => triviaTestHost(triviaFlowUnderTest()));
    await mcSettle(tester);
    var bar = tester.widget<McAppBar>(find.byType(McAppBar));
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Trivia');

    currentSpec = (category: 'all', difficulty: 'easy', seed: 42);
    final round = await currentRound(tester);
    await tester.tap(find.byKey(setupStartKey));
    await tester.pump();
    // The page slides in; the round runs meanwhile (no settle: the
    // countdown keeps drawing frames).
    await tester.pump(const Duration(seconds: 1));
    bar = tester.widget<McAppBar>(find.byType(McAppBar).last);
    expect(bar.leading, isA<IconButton>());
    expect((bar.leading! as IconButton).key, playQuitKey);
    expect(bar.title, 'Question 1 of 10');
    // Answer the open question as it stands, then the rest at once.
    await tester.tap(
      find.byKey(
        playChoiceKey(
          shownQuestion(tester, round)['correctChoiceId']! as String,
        ),
      ),
    );
    await tester.pump();
    await tapNext(tester);
    for (final token in parseAnswerTokens('W0x9')) {
      await playQuestion(tester, round, token);
      await tapNext(tester);
    }
    await mcSettle(tester);
    bar = tester.widget<McAppBar>(find.byType(McAppBar).last);
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Results');
  });

  mcTestWidgets('T-0064-AC1 a setup built under another screen loads nothing '
      'until it is shown, then once; covered and shown again it reads no '
      'categories again', (tester) async {
    serveTrivia();
    await ensureTriviaContainer();
    final session = McTestSession.current;
    await tester.pumpWidget(
      McTestApp(session: session, home: triviaTestHost(triviaFlowUnderTest())),
    );
    final navigator = Navigator.of(
      tester.element(find.byType(TriviaQuizFlow)),
    );
    Future<void> cover() => navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('cover')),
      ),
    );
    unawaited(cover());
    await mcSettle(tester);
    expect(find.text('cover'), findsOneWidget);
    expect(requests('GET', '/v1/trivia/categories'), 0);

    navigator.pop();
    await mcSettle(tester);
    expect(requests('GET', '/v1/trivia/categories'), 1);
    expect(find.byKey(setupBodyKey), findsOneWidget);

    unawaited(cover());
    await mcSettle(tester);
    navigator.pop();
    await mcSettle(tester);
    expect(requests('GET', '/v1/trivia/categories'), 1, reason: 'one visit');
    expect(requests('GET', '/v1/me/trivia/best'), 0, reason: 'signed out');
  });

  mcTestWidgets('T-0064-AC6 a round covered by another screen stops its '
      'countdown, and it goes on when the round is shown again', (
    tester,
  ) async {
    serveTrivia();
    await openRound(tester);
    await tester.pump(const Duration(milliseconds: 5000));
    final navigator = Navigator.of(
      tester.element(find.byKey(playPromptKey)),
      rootNavigator: true,
    );
    unawaited(
      navigator.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => const Scaffold(body: Text('cover')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60000));
    navigator.pop();
    await tester.pump();
    expect(countdownLabel(tester), secondsLeftLabel(15));
    expect(find.byKey(playNextKey), findsNothing, reason: 'still open');
    await tester.pump(const Duration(milliseconds: 14999));
    expect(find.byKey(playNextKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(playNextKey), findsOneWidget, reason: 'timed out');
  });

  mcTestWidgets('T-0064-AC6 the hint experiment is read once per round: a '
      'change during the round changes nothing', (tester) async {
    serveTrivia();
    await openRound(tester);
    expect(find.byKey(playHintKey), findsNothing);
    McTestSession.current.flags.forceVariant('trivia_hint', 'hint');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(playHintKey), findsNothing);
  });

  mcTestWidgets('T-0064-AC5 a linked round without a seed draws one from the '
      'seed source, once: a Retry plays the same round', (tester) async {
    serveTrivia();
    nextSeeds().addAll([7, 9]);
    McTestSession.current.backend.fail(
      'GET /v1/trivia/rounds',
      BackendFailure.serverError,
    );
    await openRound(tester, seed: null);
    await mcSettle(tester);
    expect(find.text('This round could not be loaded.'), findsOneWidget);
    McTestSession.current.backend.recover();
    await tester.tap(find.text('Retry'));
    await landAtOnce(tester);
    final asked = [
      for (final r in McTestSession.current.backend.requests)
        if (r.path == '/v1/trivia/rounds') r.query['seed'],
    ];
    expect(asked.toSet(), {'7'}, reason: 'every request, retries included');
    expect(nextSeeds(), [9], reason: 'one seed drawn');
    expect(find.byKey(playPromptKey), findsOneWidget);
  });
}

class _NobodySignedIn implements SessionReader {
  @override
  AuthStatus get status => AuthStatus.signedOut;
  @override
  bool get isSignedIn => false;
  @override
  String? get userId => null;
  @override
  String? get accessToken => null;
  @override
  String? get refreshToken => null;
  @override
  int get epoch => 0;
  @override
  Stream<AuthStatus> get authState => const Stream.empty();
}

class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) {}
  @override
  void trackScreen(String name) {}
}
