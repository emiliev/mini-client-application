import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:characters_details/characters_details.dart' as details;
import 'package:characters_list/characters_list.dart';
import 'package:characters_search/characters_search.dart' as search;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// Stands in for the real list (which needs the backend), so the test is
/// about the wiring.
class _FakeList extends CharactersListFlow {
  const _FakeList({required super.navigator});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('fake.characters'));
}

/// Stands in for the real profile (which needs the backend). It shows which
/// id the route asked for.
class _FakeDetails extends details.CharacterDetailsFlow {
  const _FakeDetails({required super.navigator, required super.characterId});

  @override
  Widget build(BuildContext context) => Text(
    'fake character ${characterId.value}',
    key: const Key('fake.character.details'),
  );
}

/// Stands in for the real search (which needs the backend). It shows which
/// query the route asked for.
class _FakeSearch extends search.CharactersSearchFlow {
  const _FakeSearch({required super.navigator, super.initialQuery});

  @override
  Widget build(BuildContext context) => Text(
    'fake search ${initialQuery ?? '-'}',
    key: const Key('fake.characters.search'),
  );
}

class _Targets implements UniverseRouteTargets {
  @override
  CharactersListFlow characters() =>
      _FakeList(navigator: diContainer<CharactersListNavigator>());

  @override
  search.CharactersSearchFlow charactersSearch({String? query}) => _FakeSearch(
    navigator: diContainer<search.CharactersSearchNavigator>(),
    initialQuery: query,
  );

  @override
  details.CharacterDetailsFlow characterDetails(int id) => _FakeDetails(
    navigator: diContainer<details.CharacterDetailsNavigator>(),
    characterId: details.CharacterId(id),
  );
}

/// Another group's route the navigator reaches through `AppLocations`
/// (publishing_wiring owns it; a wiring never imports another wiring).
final GoRoute _comicsStandIn = GoRoute(
  path: '/comics/:id',
  builder: (context, state) => Text('comic ${state.pathParameters['id']}'),
);

/// Every [GoRoute] under [routes], depth first.
Iterable<GoRoute> _goRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
    }
    yield* _goRoutes(route.routes);
  }
}

/// The test root plus the router wiring and the universe navigators, over
/// the session's strict backend (identity routes served), with the comics
/// stand-in next to the universe routes.
Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = '/characters',
}) async {
  final session = McTestSession.current
    ..backend.useFixtureSet('identity.default');
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [
      RouterDIInitializer(ref),
      const UniverseNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) => getIt.registerSingleton<UniverseRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [
        ...universeRoutes,
        _comicsStandIn,
        standInSignInRoute(signIn: _signInFixtureUser),
      ],
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

/// What the stand-in's "Sign in" does: the real `AuthApi` signs the first
/// fixture user in; true when it did.
Future<bool> _signInFixtureUser() async {
  final user = fixtureUsers.first;
  final result = await diContainer<AuthApi>().signIn(
    email: user.email,
    password: user.password,
  );
  return result.getOrNull() != null;
}

/// Lets the session's real file write finish (F-0038), then settles, until
/// the stand-in sign-in screen is gone.
Future<void> _settleRealIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (find.byKey(standInSignInKey).evaluate().isEmpty) {
      return;
    }
  }
  fail('the sign-in sheet did not close');
}

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets('T-0033-AC1 the navigator opens CharacterDetailsRoute and the '
      'flow shows the id', (tester) async {
    final router = await _boot(tester);
    expect(find.byKey(const Key('fake.characters')), findsOneWidget);

    diContainer<CharactersListNavigator>().openCharacter(const CharacterId(42));
    await tester.pumpAndSettle();

    expect(
      router.state.uri.toString(),
      const CharacterDetailsRoute(id: 42).location,
    );
    expect(find.byKey(const Key('fake.character.details')), findsOneWidget);
    expect(find.text('fake character 42'), findsOneWidget);
  });

  mcTestWidgets('T-0033-AC1 the navigator pushes: Back returns to the list and '
      'the router keeps the list as its location', (tester) async {
    final router = await _boot(tester);

    diContainer<CharactersListNavigator>().openCharacter(const CharacterId(42));
    await tester.pumpAndSettle();
    // A `go` would make details the router's own location; a push leaves the
    // list there and stacks details on top.
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      AppLocations.characters,
    );
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake.characters')), findsOneWidget);
    expect(find.byKey(const Key('fake.character.details')), findsNothing);
  });

  mcTestWidgets('T-0033-AC1 the navigator pushes to the live router after the '
      'router was replaced, not to the one it first saw', (tester) async {
    final first = await _boot(tester);
    final ref = diContainer<RouterRef>();
    // The navigator is created (and, in the old design, captured `first`).
    final navigator = diContainer<CharactersListNavigator>();
    navigator.openCharacter(const CharacterId(1));
    await tester.pumpAndSettle();
    expect(first.state.uri.toString(), '/characters/1');

    ref.detach();
    final second = ref.attach(
      GoRouter(initialLocation: '/characters', routes: universeRoutes),
    );
    addTearDown(second.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: second));
    navigator.openCharacter(const CharacterId(2));
    await tester.pumpAndSettle();

    expect(second.state.uri.toString(), '/characters/2');
    expect(find.text('fake character 2'), findsOneWidget);
  });

  mcTestWidgets('T-0041-AC5 openComic pushes the comic location of the '
      'publishing group', (tester) async {
    final router = await _boot(tester);

    diContainer<CharactersListNavigator>().openComic(const ComicId(501267));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(501267));
    expect(find.text('comic 501267'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'a push: Back returns to the list');
  });

  mcTestWidgets('T-0067-AC3 the profile\'s openComic pushes the comic '
      'location, and Back returns to the profile', (tester) async {
    final router = await _boot(tester, initial: '/characters/100001');
    expect(find.text('fake character 100001'), findsOneWidget);

    diContainer<details.CharacterDetailsNavigator>().openComic(
      const details.ComicId(500138),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(500138));
    expect(find.text('comic 500138'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('fake character 100001'), findsOneWidget);
    expect(find.text('comic 500138'), findsNothing);
  });

  mcTestWidgets('T-0067-AC3 T-0066-AC3 the profile\'s requestSignIn opens '
      'the sign-in screen for the favourite: Sign in signs the fixture user '
      'in and answers true', (
    tester,
  ) async {
    await _boot(tester, initial: '/characters/100001');
    final reader = diContainer<SessionReader>();
    expect(reader.isSignedIn, isFalse);

    final answer = diContainer<details.CharacterDetailsNavigator>()
        .requestSignIn();
    await tester.pumpAndSettle();
    expect(find.byKey(standInSignInKey), findsOneWidget);
    expect(find.text(standInSignInText('favourites')), findsOneWidget);

    await tester.tap(find.byKey(standInSignInConfirmKey));
    await _settleRealIo(tester);

    expect(await answer, isTrue);
    expect(reader.userId, fixtureUsers.first.id);
    expect(find.byKey(standInSignInKey), findsNothing);
  });

  mcTestWidgets('T-0067-AC3 the profile\'s requestSignIn: Not now answers '
      'false and leaves the user signed out', (tester) async {
    await _boot(tester, initial: '/characters/100001');

    final answer = diContainer<details.CharacterDetailsNavigator>()
        .requestSignIn();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(standInSignInNotNowKey));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
  });

  mcTestWidgets('T-0067-AC3 requestSignIn answers true at once when someone '
      'is already signed in, with no sign-in screen', (tester) async {
    await _boot(tester, initial: '/characters/100001');
    final user = fixtureUsers.first;
    final signedIn = await tester.runAsync(
      () => diContainer<AuthApi>().signIn(
        email: user.email,
        password: user.password,
      ),
    );
    expect(signedIn?.getOrNull()?.id, user.id);

    final answer = diContainer<details.CharacterDetailsNavigator>()
        .requestSignIn();
    await tester.pumpAndSettle();

    expect(await answer, isTrue);
    expect(find.byKey(standInSignInKey), findsNothing);
  });

  mcTestWidgets('T-0033-AC1 the wiring initializer resolves the route targets '
      'and the navigators', (tester) async {
    final session = McTestSession.current;
    final ref = RouterRef();
    await McTestContainer.initialize(
      session,
      wirings: [RouterDIInitializer(ref), const UniverseWiringDIInitializer()],
    );
    // Lazy: a navigator needs the router, which only exists after boot.
    final router = ref.attach(GoRouter(routes: universeRoutes));
    addTearDown(router.dispose);

    expect(diContainer<UniverseRouteTargets>(), isA<UniverseRouteTargets>());
    expect(
      diContainer<CharactersListNavigator>(),
      same(diContainer<CharactersListNavigator>()),
      reason: 'a lazy singleton',
    );
    expect(
      diContainer<details.CharacterDetailsNavigator>(),
      same(diContainer<details.CharacterDetailsNavigator>()),
      reason: 'a lazy singleton',
    );
  });

  mcTestWidgets(
    'T-0041-AC8 T-0067-AC3 the route targets build each flow with the wiring '
    'navigator',
    (tester) async {
      final session = McTestSession.current;
      final ref = RouterRef();
      await McTestContainer.initialize(
        session,
        wirings: [
          RouterDIInitializer(ref),
          const UniverseWiringDIInitializer(),
        ],
      );
      final router = ref.attach(GoRouter(routes: universeRoutes));
      addTearDown(router.dispose);

      final targets = diContainer<UniverseRouteTargets>();
      expect(
        targets.characters().navigator,
        same(diContainer<CharactersListNavigator>()),
      );
      final profile = targets.characterDetails(7);
      expect(profile.characterId, const details.CharacterId(7));
      expect(
        profile.navigator,
        same(diContainer<details.CharacterDetailsNavigator>()),
      );
    },
  );

  test('T-0033-AC2 every AppLocations entry equals its typed route', () {
    final drift = <String, ({String location, String route})>{
      'characters': (
        location: AppLocations.characters,
        route: const CharactersRoute().location,
      ),
      'character(7)': (
        location: AppLocations.character(7),
        route: const CharacterDetailsRoute(id: 7).location,
      ),
      'charactersSearch()': (
        location: AppLocations.charactersSearch(),
        route: const CharactersSearchRoute().location,
      ),
      'charactersSearch(spi)': (
        location: AppLocations.charactersSearch('spi'),
        route: const CharactersSearchRoute(q: 'spi').location,
      ),
      'charactersSearch(a & b)': (
        location: AppLocations.charactersSearch('Spire W & #1'),
        route: const CharactersSearchRoute(q: 'Spire W & #1').location,
      ),
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above (the search
    // is in it three times, as the typed route has three shapes).
    expect(_goRoutes(universeRoutes), hasLength(drift.length - 2));
  });
  mcTestWidgets('T-0071-AC4 the list\'s openSearch pushes the search location, '
      'and Back returns to the list', (tester) async {
    final router = await _boot(tester);

    diContainer<CharactersListNavigator>().openSearch();
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/characters/search');
    expect(
      router.state.uri.toString(),
      AppLocations.charactersSearch(),
      reason: 'AppLocations is the same place',
    );
    expect(find.text('fake search -'), findsOneWidget);
    expect(find.byKey(const Key('fake.characters')), findsNothing);
    expect(router.canPop(), isTrue, reason: 'a push: Back returns');

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake.characters')), findsOneWidget);
    expect(find.byKey(const Key('fake.characters.search')), findsNothing);
  });

  mcTestWidgets('T-0071-AC4 the search\'s openCharacter pushes the profile '
      'location, and Back returns to the search', (tester) async {
    final router = await _boot(tester, initial: '/characters/search?q=a');
    expect(find.text('fake search a'), findsOneWidget);

    diContainer<search.CharactersSearchNavigator>().openCharacter(
      const search.CharacterId(100486),
    );
    await tester.pumpAndSettle();

    expect(
      router.state.uri.toString(),
      const CharacterDetailsRoute(id: 100486).location,
    );
    expect(find.text('fake character 100486'), findsOneWidget);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('fake search a'), findsOneWidget);
    expect(find.text('fake character 100486'), findsNothing);
  });

  for (final (link, shown) in [
    ('/characters/search', 'fake search -'),
    ('/characters/search?q=a', 'fake search a'),
    (
      '/characters/search?q=Spire%20W%20%26%20%231',
      'fake search Spire W & #1',
    ),
  ]) {
    mcTestWidgets(
      'T-0071-AC5 the link $link builds the search flow with its query, '
      'before the :id route can take "search"',
      (tester) async {
        await _boot(tester, initial: link);

        expect(find.text(shown), findsOneWidget);
        expect(find.textContaining('fake character'), findsNothing);
      },
    );
  }

  mcTestWidgets(
    'T-0071-AC5 a link to the search opens with the list under it',
    (tester) async {
      final router = await _boot(tester, initial: '/characters/search?q=a');

      expect(find.text('fake search a'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'the list is the screen below');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake.characters')), findsOneWidget);
    },
  );

  mcTestWidgets('T-0071-AC4 the route targets build the search with the '
      'wiring navigator and the query', (tester) async {
    final session = McTestSession.current;
    final ref = RouterRef();
    await McTestContainer.initialize(
      session,
      wirings: [RouterDIInitializer(ref), const UniverseWiringDIInitializer()],
    );
    final router = ref.attach(GoRouter(routes: universeRoutes));
    addTearDown(router.dispose);

    final targets = diContainer<UniverseRouteTargets>();
    final flow = targets.charactersSearch(query: 'spi');
    expect(flow.initialQuery, 'spi');
    expect(
      flow.navigator,
      same(diContainer<search.CharactersSearchNavigator>()),
    );
    expect(targets.charactersSearch().initialQuery, isNull);
    expect(
      diContainer<search.CharactersSearchNavigator>(),
      same(diContainer<search.CharactersSearchNavigator>()),
      reason: 'a lazy singleton',
    );
  });
}
