import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockTriviaQuizNavigator extends Mock implements TriviaQuizNavigator {}

final Expando<MockTriviaQuizNavigator> _navigators = Expando('trivia nav');
final Expando<List<Completer<bool>>> _signIns = Expando('trivia sign-ins');
final Expando<List<String>> _calls = Expando('trivia navigator calls');
final Expando<List<int>> _seeds = Expando('trivia seeds');
final Expando<bool> _reduceMotion = Expando('trivia reduce motion');
final Expando<Map<String, Map<String, Object?>>> _rounds = Expando('rounds');

/// The running test's navigator mock: one per test, keyed by its session.
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`).
MockTriviaQuizNavigator triviaNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

/// Every hand-over the feature asked the app for, in order (`comic 501501`).
List<String> navigatorCalls() => _calls[McTestSession.current] ??= [];

/// The sign-ins the feature asked for and nobody answered yet, oldest first.
List<Completer<bool>> pendingSignIns() =>
    _signIns[McTestSession.current] ??= [];

MockTriviaQuizNavigator _newNavigator() {
  final navigator = MockTriviaQuizNavigator();
  when(() => navigator.openComic(any())).thenAnswer(
    (i) => navigatorCalls().add(
      'comic ${(i.positionalArguments.single as ComicId).value}',
    ),
  );
  when(navigator.requestSignIn).thenAnswer((_) {
    navigatorCalls().add('sign in');
    final answer = Completer<bool>();
    pendingSignIns().add(answer);
    return answer.future;
  });
  return navigator;
}

/// The test root, once per test (unless an earlier step made it).
Future<void> ensureTriviaContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}

final Expando<int> _skew = Expando('trivia clock skew');

/// The quiz's clock in a feature test: the widget-test binding's fake clock,
/// which `tester.pump(d)` moves together with the fake timers (ADR-0014),
/// plus the [clockAhead] skew.
int triviaClock() =>
    TestWidgetsFlutterBinding.instance.clock.now().millisecondsSinceEpoch +
    (_skew[McTestSession.current] ?? 0);

/// Moves the quiz's clock [ms] ahead of the fake timers, for good: what a
/// device does when the event loop is busy and a timer callback runs late
/// (the clock is a `Stopwatch`, the countdown's end a `Timer`). A tap that
/// lands in that gap is judged by its elapsed time.
void clockAhead(int ms) =>
    _skew[McTestSession.current] = (_skew[McTestSession.current] ?? 0) + ms;

/// The seeds the next rounds get, in order; 42 once they run out (the
/// contract's worked examples are seed 42).
List<int> nextSeeds() => _seeds[McTestSession.current] ??= [];

int triviaNextSeed() {
  final seeds = nextSeeds();
  return seeds.isEmpty ? 42 : seeds.removeAt(0);
}

/// Whether the test host asks for reduce motion (`disableAnimations`).
bool get reduceMotion => _reduceMotion[McTestSession.current] ?? false;
set reduceMotion(bool on) => _reduceMotion[McTestSession.current] = on;

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production), and the
/// reduce-motion setting.
Widget triviaTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: flow,
      ),
    ),
  ),
);

/// The flow as the app builds it, over the session's navigator mock; at a
/// round when [category] and [difficulty] are given.
Widget triviaFlowUnderTest({
  String? category,
  String? difficulty,
  int? seed,
}) => TriviaQuizFlow(
  navigator: triviaNavigator(),
  clock: triviaClock,
  nextSeed: triviaNextSeed,
  category: category,
  difficulty: difficulty,
  seed: seed,
);

// --- keys (plan 05 §3.5: steps find by key, never by a feature widget type)

const setupBodyKey = ValueKey<String>('trivia_setup.body');
const setupStartKey = ValueKey<String>('trivia_setup.start');
ValueKey<String> setupCategoryKey(String id) =>
    ValueKey('trivia_setup.category.$id');
ValueKey<String> setupBestKey(String id) => ValueKey('trivia_setup.best.$id');
ValueKey<String> setupDifficultyKey(String d) =>
    ValueKey('trivia_setup.difficulty.$d');

const playQuitKey = ValueKey<String>('trivia_play.quit');
const playPromptKey = ValueKey<String>('trivia_play.prompt');
const playNextKey = ValueKey<String>('trivia_play.next');
const playHintKey = ValueKey<String>('trivia_play.hint');
const playFeedbackKey = ValueKey<String>('trivia_play.feedback');
const playScoreKey = ValueKey<String>('trivia_play.score');
ValueKey<String> playChoiceKey(String id) => ValueKey('trivia_play.choice.$id');
const countdownKey = ValueKey<String>('trivia_play.countdown');
const countdownRingKey = ValueKey<String>('trivia_play.countdown.ring');
const countdownNumberKey = ValueKey<String>('trivia_play.countdown.number');
const streakMeterKey = ValueKey<String>('trivia_play.streak');

const resultsBodyKey = ValueKey<String>('trivia_results.body');
const resultsScoreKey = ValueKey<String>('trivia_results.score');
const resultsCorrectKey = ValueKey<String>('trivia_results.correct');
const resultsBestKey = ValueKey<String>('trivia_results.best');
const resultsNewBestKey = ValueKey<String>('trivia_results.new_best');
const resultsStatusKey = ValueKey<String>('trivia_results.status');
const resultsRetryKey = ValueKey<String>('trivia_results.retry');
const resultsSaveKey = ValueKey<String>('trivia_results.save');
const resultsPlayAgainKey = ValueKey<String>('trivia_results.play_again');
const breakdownDonutKey = ValueKey<String>('trivia_results.donut');
const breakdownBarsKey = ValueKey<String>('trivia_results.bars');
ValueKey<String> resultsComicKey(int index) =>
    ValueKey('trivia_results.comic.$index');

// --- fixture facts (mc_fixtures_editorial CONTRACT.md, backend seed 42) ---

typedef Json = Map<String, Object?>;

/// The round the backend serves for these three values, read straight from
/// the backend engine (no request through the app's `Dio`, so the harness
/// records nothing): test-facing facts come from the fixture package, never
/// from feature code.
Future<Json> fixtureRound(
  WidgetTester tester, {
  required String category,
  required String difficulty,
  required int seed,
}) async {
  final key = '$category/$difficulty/$seed';
  final cache = _rounds[McTestSession.current] ??= {};
  final cached = cache[key];
  if (cached != null) {
    return cached;
  }
  // A backend of its own: the facts do not depend on the scenario's
  // failures, holds or scenarios.
  final dio = MockBackend(domains: [const TriviaMockDomain()]).createDio();
  final response = await tester.runAsync(
    () => dio.get<Map<String, Object?>>(
      'v1/trivia/rounds',
      queryParameters: {
        'category': category,
        'difficulty': difficulty,
        'seed': '$seed',
      },
    ),
  );
  expect(response?.statusCode, 200, reason: 'the fixture round $key');
  return cache[key] = response!.data!;
}

List<Json> questionsOf(Json round) =>
    (round['questions']! as List).cast<Json>();

/// The round a scenario plays: set by the steps that open or start one.
typedef RoundSpec = ({String category, String difficulty, int seed});

final Expando<RoundSpec> _spec = Expando('trivia round spec');
final Expando<List<ShownQuestion>> _shown = Expando('trivia shown');
final Expando<({String category, String difficulty})> _picked = Expando(
  'trivia picked',
);

/// The round under test: the last one opened or started.
RoundSpec get currentSpec =>
    _spec[McTestSession.current] ??
    (throw StateError('No round was opened or started yet'));
set currentSpec(RoundSpec spec) => _spec[McTestSession.current] = spec;

/// What the setup has selected, as the steps picked it (the page starts on
/// `all` and `easy`).
({String category, String difficulty}) get pickedOnSetup =>
    _picked[McTestSession.current] ?? (category: 'all', difficulty: 'easy');
set pickedOnSetup(({String category, String difficulty}) picked) =>
    _picked[McTestSession.current] = picked;

/// The seed the next round started from the setup or Play again gets.
int peekNextSeed() => nextSeeds().isEmpty ? 42 : nextSeeds().first;

/// The fixture round of [currentSpec].
Future<Json> currentRound(WidgetTester tester) {
  final spec = currentSpec;
  return fixtureRound(
    tester,
    category: spec.category,
    difficulty: spec.difficulty,
    seed: spec.seed,
  );
}

/// One question as it was first shown: its prompt, how many choices were
/// on screen, and the countdown's label.
typedef ShownQuestion = ({String prompt, int choices, String countdown});

/// Every question shown so far, in order (recorded by [playQuestion]).
List<ShownQuestion> shownQuestions() => _shown[McTestSession.current] ??= [];

/// The choice buttons on screen now.
int visibleChoices() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('trivia_play.choice.'),
    )
    .evaluate()
    .length;

/// The countdown's accessible label ("20 seconds left").
String countdownLabel(WidgetTester tester) =>
    tester.widget<Semantics>(find.byKey(countdownKey)).properties.label!;

/// The English label of [seconds] left, built here (an oracle).
String secondsLeftLabel(int seconds) =>
    seconds == 1 ? '1 second left' : '$seconds seconds left';

/// The fixture question whose prompt is on screen now.
Json shownQuestion(WidgetTester tester, Json round) {
  final prompt = tester.widget<Text>(find.byKey(playPromptKey)).data;
  return questionsOf(round).firstWhere(
    (q) => q['prompt'] == prompt,
    orElse: () => fail('"$prompt" is not a question of ${round['roundId']}'),
  );
}

/// The best scores of [email] on the backend (a minted token).
Future<Map<String, int>> backendBest(WidgetTester tester, String email) async {
  final dio = McTestSession.current.backend.backend.createDio();
  final response = await tester.runAsync(
    () => dio.get<Map<String, Object?>>(
      'v1/me/trivia/best',
      options: Options(
        headers: {
          'Authorization':
              'Bearer ${mintAccessToken(fixtureUser(email).id, 1)}',
        },
      ),
    ),
  );
  return {
    for (final b in (response!.data!['best']! as List).cast<Json>())
      b['category']! as String: b['bestScore']! as int,
  };
}

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// Signs [email] in through the real `AuthApi` of the test container
/// (inside `runAsync`: the session saves to a real file, F-0038).
Future<void> signIn(WidgetTester tester, String email) async {
  final user = fixtureUser(email);
  final result = await tester.runAsync(
    () => diContainer<AuthApi>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
}

/// Lets what is on its way land without moving fake time: Dio's zero-delay
/// timers and a few frames. A question's clock does not move.
Future<void> landAtOnce(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(Duration.zero);
  }
}

/// A "no answer" token in the contract (`N<ms>`): the app has no way to
/// skip a question, so it is played as letting the time run out; its
/// points (0) and its effect on the streak (a reset) are the same.
typedef AnswerToken = ({String kind, int elapsedMs, bool hint});

/// Parses the contract's answer notation (`C0 W0x9`, `C0h`): kind, elapsed
/// ms, an optional `h` (the hint), and `xN` to repeat.
List<AnswerToken> parseAnswerTokens(String spec) {
  final token = RegExp(r'^([CWN])(\d+)(h)?(?:x(\d+))?$');
  return [
    for (final t in spec.split(' '))
      if (token.firstMatch(t) case final m?)
        for (var i = 0; i < int.parse(m.group(4) ?? '1'); i++)
          (
            kind: m.group(1)!,
            elapsedMs: int.parse(m.group(2)!),
            hint: m.group(3) != null,
          )
      else
        throw FormatException('bad answer token', t),
  ];
}

/// Plays the question on screen as [token] says, on [round] (the fixture
/// round): the hint first if asked for, then [token.elapsedMs] of fake time,
/// then the choice (a no-answer lets the time run out). Ends with the
/// question revealed; does not tap Next.
Future<void> playQuestion(
  WidgetTester tester,
  Json round,
  AnswerToken token,
) async {
  final question = shownQuestion(tester, round);
  shownQuestions().add((
    prompt: question['prompt']! as String,
    choices: visibleChoices(),
    countdown: countdownLabel(tester),
  ));
  if (token.hint) {
    final hint = find.byKey(playHintKey);
    expect(hint, findsOneWidget, reason: 'the hint is offered');
    await tester.tap(hint);
    await tester.pump();
  }
  final limit = (question['timeLimitSeconds']! as int) * 1000;
  final choice = switch (token.kind) {
    'C' => question['correctChoiceId']! as String,
    'W' => _visibleWrongChoice(question),
    _ => null,
  };
  // On screen first (a jump, no time passes): at 2x a long prompt can push
  // the choices below the fold.
  if (choice != null) {
    await tester.ensureVisible(find.byKey(playChoiceKey(choice)));
    await tester.pump();
  }
  if (choice == null) {
    // No answer: the countdown's own timer ends the question at the limit.
    await tester.pump(Duration(milliseconds: token.elapsedMs + limit));
  } else if (token.elapsedMs < limit) {
    if (token.elapsedMs > 0) {
      await tester.pump(Duration(milliseconds: token.elapsedMs));
    }
    await tester.tap(find.byKey(playChoiceKey(choice)));
  } else {
    // A tap at or past the limit, before the countdown's timer has run (the
    // timer is due at the limit): one millisecond before it, the clock runs
    // ahead to the token's time, and the tap lands. The engine judges it by
    // its elapsed time, a timeout, as the server does.
    await tester.pump(Duration(milliseconds: limit - 1));
    clockAhead(token.elapsedMs - (limit - 1));
    await tester.tap(find.byKey(playChoiceKey(choice)));
  }
  await tester.pump();
  await tester.scrollUntilVisible(
    find.byKey(playNextKey),
    200,
    scrollable: playScrollable(),
  );
  expect(find.byKey(playNextKey), findsOneWidget, reason: 'it is revealed');
}

/// The play page's scrolling body.
Finder playScrollable() => find
    .ancestor(of: find.byKey(playPromptKey), matching: find.byType(Scrollable))
    .first;

String _visibleWrongChoice(Json question) {
  for (final c in (question['choices']! as List).cast<Json>()) {
    final id = c['id']! as String;
    if (id != question['correctChoiceId'] &&
        find.byKey(playChoiceKey(id)).evaluate().isNotEmpty) {
      return id;
    }
  }
  return fail('no wrong choice is shown');
}

/// Taps Next (or See results) and lets the next question or the results
/// show, without moving fake time.
Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(playNextKey));
  await landAtOnce(tester);
}

/// The text of the widget with [key].
String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  // `any()` for the navigator's argument type (an int at run time).
  registerFallbackValue(const ComicId(0));
  editorialFixtureSets.forEach(McFixtureSets.register);
  identityFixtureSets.forEach(McFixtureSets.register);
}
