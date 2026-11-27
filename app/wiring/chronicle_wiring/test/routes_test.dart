import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:chronicle_wiring/chronicle_wiring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:trivia_quiz/trivia_quiz.dart';

/// Stands in for the real quiz (which needs the trivia backend), so the test
/// is about the wiring. It shows which round the route asked for.
class _FakeQuiz extends TriviaQuizFlow {
  const _FakeQuiz({
    required super.navigator,
    super.category,
    super.difficulty,
    super.seed,
  }) : super(clock: _noClock, nextSeed: _noSeed);

  static int _noClock() => 0;
  static int _noSeed() => 0;

  @override
  Widget build(BuildContext context) => Text(
    category == null ? 'fake setup' : 'fake round $category $difficulty $seed',
    key: const Key('fake.quiz'),
  );
}

class _Targets implements ChronicleRouteTargets {
  @override
  TriviaQuizFlow trivia() =>
      _FakeQuiz(navigator: diContainer<TriviaQuizNavigator>());

  @override
  TriviaQuizFlow triviaRound({
    String? category,
    String? difficulty,
    int? seed,
  }) => _FakeQuiz(
    navigator: diContainer<TriviaQuizNavigator>(),
    category: category ?? 'all',
    difficulty: difficulty ?? 'easy',
    seed: seed,
  );
}

/// The publishing group's comic route, which the navigator reaches through
/// `AppLocations` (a wiring never imports another wiring).
final List<GoRoute> _standIns = [
  GoRoute(
    path: '/comics/:id',
    builder: (context, state) => Text(
      'comic ${state.pathParameters['id']}',
      key: const Key('stand-in.comic'),
    ),
  ),
];

Iterable<GoRoute> _goRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
    }
    yield* _goRoutes(route.routes);
  }
}

Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = '/trivia',
}) async {
  final ref = RouterRef();
  await McTestContainer.initialize(
    McTestSession.current,
    wirings: [
      RouterDIInitializer(ref),
      const ChronicleNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) =>
            getIt.registerSingleton<ChronicleRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [...chronicleRoutes, ..._standIns, standInSignInRoute()],
      errorBuilder: (context, state) =>
          Text('not found ${state.uri}', key: const Key('not.found')),
    ),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: McTheme.of(McTestSession.current.themeVariant),
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets('T-0064-AC3 /trivia builds the quiz at its setup', (
    tester,
  ) async {
    final router = await _boot(tester, initial: AppLocations.trivia);
    expect(router.state.uri.toString(), '/trivia');
    expect(find.text('fake setup'), findsOneWidget);
  });

  mcTestWidgets('T-0064-AC5 /trivia/play opens the quiz at that round, over '
      'the setup', (tester) async {
    final router = await _boot(
      tester,
      initial: AppLocations.triviaPlay(
        category: 'characters',
        difficulty: 'easy',
        seed: 42,
      ),
    );
    expect(find.text('fake round characters easy 42'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'the setup is below it');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake setup'), findsOneWidget);
  });

  mcTestWidgets('T-0064-AC5 /trivia/play with no values plays all/easy with a '
      'new seed', (tester) async {
    await _boot(tester, initial: AppLocations.triviaPlay());
    expect(find.text('fake round all easy null'), findsOneWidget);
  });

  mcTestWidgets('T-0064-AC5 the link forms normalise to the trivia routes', (
    tester,
  ) async {
    expect(
      PendingLinks.normalise('miniclient://app/trivia'),
      AppLocations.trivia,
    );
    final link = PendingLinks.normalise(
      'miniclient://app/trivia/play?category=characters&difficulty=easy&seed=42',
    );
    expect(
      link,
      AppLocations.triviaPlay(
        category: 'characters',
        difficulty: 'easy',
        seed: 42,
      ),
    );
    await _boot(tester, initial: link);
    expect(find.text('fake round characters easy 42'), findsOneWidget);
  });

  mcTestWidgets('T-0064-AC3 openComic pushes the comic location, and Back '
      'returns to the quiz', (tester) async {
    final router = await _boot(tester);

    diContainer<TriviaQuizNavigator>().openComic(const ComicId(501507));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(501507));
    expect(find.text('comic 501507'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake setup'), findsOneWidget);
  });

  mcTestWidgets('T-0064-AC3 requestSignIn: signed in it answers true at '
      'once, with no sign-in screen', (tester) async {
    McTestSession.current.backend.useFixtureSet('identity.default');
    await _boot(tester);
    final user = fixtureUsers.first;
    await tester.runAsync(
      () => diContainer<AuthApi>().signIn(
        email: user.email,
        password: user.password,
      ),
    );

    expect(await diContainer<TriviaQuizNavigator>().requestSignIn(), isTrue);
    expect(find.byKey(standInSignInKey), findsNothing);
  });

  mcTestWidgets('T-0064-AC3 requestSignIn: signed out it opens the sign-in '
      'screen for the trivia results, and Not now answers false', (
    tester,
  ) async {
    await _boot(tester);

    var answered = false;
    bool? answer;
    final pending = diContainer<TriviaQuizNavigator>().requestSignIn().then((
      a,
    ) {
      answered = true;
      answer = a;
    });
    await tester.pumpAndSettle();
    expect(find.text(standInSignInText('triviaResults')), findsOneWidget);
    expect(answered, isFalse);

    await tester.tap(find.byKey(standInSignInNotNowKey));
    await tester.pumpAndSettle();
    await pending;
    expect(answer, isFalse);
  });

  mcTestWidgets('T-0064-AC5 the wiring initializer registers the navigator '
      'and route targets that build the real flow', (tester) async {
    final ref = RouterRef();
    await McTestContainer.initialize(
      McTestSession.current,
      wirings: [RouterDIInitializer(ref), const ChronicleWiringDIInitializer()],
    );
    final router = ref.attach(GoRouter(routes: chronicleRoutes));
    addTearDown(router.dispose);

    final targets = diContainer<ChronicleRouteTargets>();
    final setup = targets.trivia();
    expect(setup.navigator, same(diContainer<TriviaQuizNavigator>()));
    expect(setup.category, isNull);
    expect(setup.clock, chronicleClock);
    expect(setup.nextSeed, chronicleSeed);
    final round = targets.triviaRound(
      category: 'comics',
      difficulty: 'hard',
      seed: 7,
    );
    expect(
      (round.category, round.difficulty, round.seed),
      (
        'comics',
        'hard',
        7,
      ),
    );
    final defaults = targets.triviaRound();
    expect(
      (defaults.category, defaults.difficulty, defaults.seed),
      (
        'all',
        'easy',
        null,
      ),
    );
  });

  test('T-0064-AC5 the clock is monotonic milliseconds and the seeds stay in '
      'the contract range', () async {
    final before = chronicleClock();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final after = chronicleClock();
    expect(after - before, inInclusiveRange(15, 2000));
    final seeds = {for (var i = 0; i < 200; i++) chronicleSeed()};
    expect(seeds.every((s) => s >= 0 && s <= 2147483647), isTrue);
    expect(seeds.length, greaterThan(190), reason: 'they vary');
  });

  test('T-0064-AC5 every AppLocations entry of the group equals its typed '
      'route', () {
    final drift = <String, ({String location, String route})>{
      'trivia': (
        location: AppLocations.trivia,
        route: const TriviaRoute().location,
      ),
      'triviaPlay()': (
        location: AppLocations.triviaPlay(),
        route: const TriviaPlayRoute().location,
      ),
      for (final (c, d, s) in [
        ('characters', 'easy', 42),
        ('all', 'hard', 0),
        ('a b', 'Ünï/c', 2147483647),
      ])
        'triviaPlay($c, $d, $s)': (
          location: AppLocations.triviaPlay(
            category: c,
            difficulty: d,
            seed: s,
          ),
          route: TriviaPlayRoute(category: c, difficulty: d, seed: s).location,
        ),
      'triviaPlay(seed only)': (
        location: AppLocations.triviaPlay(seed: 5),
        route: const TriviaPlayRoute(seed: 5).location,
      ),
    };
    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    expect(
      {for (final r in _goRoutes(chronicleRoutes)) r.path},
      {'/trivia', 'play'},
    );
    expect(
      {for (final r in _goRoutes(chronicleRoutes)) r.name},
      {'trivia_setup', 'trivia_play'},
    );
  });
}
