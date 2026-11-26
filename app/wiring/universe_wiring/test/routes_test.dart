import 'package:app_core/app_core.dart';
import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// Stands in for the real list (which needs the backend), so the test is
/// about the wiring.
class _FakeList extends CharactersListFlow {
  const _FakeList({required super.navigator});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('fake.characters'));
}

class _Targets implements UniverseRouteTargets {
  @override
  CharactersListFlow characters() =>
      _FakeList(navigator: diContainer<CharactersListNavigator>());

  @override
  CharacterDetailsPlaceholderFlow characterDetails(int id) =>
      CharacterDetailsPlaceholderFlow(id: id);
}

/// Every [GoRoute] under [routes], depth first.
Iterable<GoRoute> _goRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
    }
    yield* _goRoutes(route.routes);
  }
}

void main() {
  setUp(resetDIContainer);
  tearDown(resetDIContainer);

  testWidgets('T-0033-AC1 the navigator opens CharacterDetailsRoute and the '
      'placeholder shows the id', (tester) async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseNavigatorsDIInitializer(),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<UniverseRouteTargets>(_Targets());
      }),
    ]);
    final router = ref.attach(
      GoRouter(
        initialLocation: AppLocations.characters,
        routes: universeRoutes,
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.byKey(const Key('fake.characters')), findsOneWidget);

    diContainer<CharactersListNavigator>().openCharacter(const CharacterId(42));
    await tester.pumpAndSettle();

    expect(
      router.state.uri.toString(),
      const CharacterDetailsRoute(id: 42).location,
    );
    expect(
      find.byKey(const Key('character.details.placeholder')),
      findsOneWidget,
    );
    expect(find.text('Character details 42'), findsOneWidget);
  });

  testWidgets('T-0033-AC1 the navigator pushes: Back returns to the list and '
      'the router keeps the list as its location', (tester) async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseNavigatorsDIInitializer(),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<UniverseRouteTargets>(_Targets());
      }),
    ]);
    final router = ref.attach(
      GoRouter(
        initialLocation: AppLocations.characters,
        routes: universeRoutes,
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

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
    expect(
      find.byKey(const Key('character.details.placeholder')),
      findsNothing,
    );
  });

  testWidgets('T-0033-AC1 the navigator pushes to the live router after the '
      'router was replaced, not to the one it first saw', (tester) async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseNavigatorsDIInitializer(),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<UniverseRouteTargets>(_Targets());
      }),
    ]);
    GoRouter build() => GoRouter(
      initialLocation: AppLocations.characters,
      routes: universeRoutes,
    );
    final first = ref.attach(build());
    await tester.pumpWidget(MaterialApp.router(routerConfig: first));
    // The navigator is created (and, in the old design, captured `first`).
    final navigator = diContainer<CharactersListNavigator>();
    navigator.openCharacter(const CharacterId(1));
    await tester.pumpAndSettle();
    expect(first.state.uri.toString(), '/characters/1');

    ref.detach();
    final second = ref.attach(build());
    addTearDown(second.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: second));
    first.dispose();
    navigator.openCharacter(const CharacterId(2));
    await tester.pumpAndSettle();

    expect(second.state.uri.toString(), '/characters/2');
    expect(
      find.byKey(const Key('character.details.placeholder')),
      findsOneWidget,
    );
    expect(find.text('Character details 2'), findsOneWidget);
  });

  testWidgets('T-0041-AC5 openComic pushes the comic location of the '
      'publishing group', (tester) async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseNavigatorsDIInitializer(),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<UniverseRouteTargets>(_Targets());
      }),
    ]);
    // publishing_wiring owns `/comics/:id`; a wiring never imports another
    // wiring, so a stand-in answers the location.
    final router = ref.attach(
      GoRouter(
        initialLocation: AppLocations.characters,
        routes: [
          ...universeRoutes,
          GoRoute(
            path: '/comics/:id',
            builder: (context, state) =>
                Text('comic ${state.pathParameters['id']}'),
          ),
        ],
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    diContainer<CharactersListNavigator>().openComic(const ComicId(501267));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(501267));
    expect(find.text('comic 501267'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'a push: Back returns to the list');
  });

  test('T-0033-AC1 the wiring initializer resolves the route targets and the '
      'navigator', () async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseWiringDIInitializer(),
    ]);
    // Lazy: a navigator needs the router, which only exists after boot.
    final router = ref.attach(GoRouter(routes: universeRoutes));
    addTearDown(router.dispose);

    expect(diContainer<UniverseRouteTargets>(), isA<UniverseRouteTargets>());
    expect(
      diContainer<CharactersListNavigator>(),
      same(diContainer<CharactersListNavigator>()),
      reason: 'a lazy singleton',
    );
  });

  test('T-0041-AC8 the route targets build each flow with the wiring '
      'navigator', () async {
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      const UniverseWiringDIInitializer(),
    ]);
    final router = ref.attach(GoRouter(routes: universeRoutes));
    addTearDown(router.dispose);

    final targets = diContainer<UniverseRouteTargets>();
    expect(
      targets.characters().navigator,
      same(diContainer<CharactersListNavigator>()),
    );
    expect(targets.characterDetails(7).id, 7);
  });

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
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above.
    expect(_goRoutes(universeRoutes), hasLength(drift.length));
  });
}
