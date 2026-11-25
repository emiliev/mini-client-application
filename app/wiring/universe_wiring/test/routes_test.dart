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

class _Targets implements RouteTargets {
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
        getIt.registerSingleton<RouteTargets>(_Targets());
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

    expect(diContainer<RouteTargets>(), isA<RouteTargets>());
    expect(
      diContainer<CharactersListNavigator>(),
      same(diContainer<CharactersListNavigator>()),
      reason: 'a lazy singleton',
    );
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
