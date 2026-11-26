import 'package:app_core/app_core.dart';
import 'package:discovery_search/discovery_search.dart';
import 'package:discovery_wiring/discovery_wiring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Stands in for the real search (which needs the discovery backend), so the
/// test is about the wiring. It shows which query the route asked for.
class _FakeSearch extends DiscoverySearchFlow {
  const _FakeSearch({required super.navigator, super.initialQuery});

  @override
  Widget build(BuildContext context) => Text(
    'fake search ${initialQuery ?? '(none)'}',
    key: const Key('fake.search'),
  );
}

class _Targets implements DiscoveryRouteTargets {
  @override
  DiscoverySearchFlow search({String? query}) => _FakeSearch(
    navigator: diContainer<DiscoverySearchNavigator>(),
    initialQuery: query,
  );
}

/// Other groups' routes the navigator reaches through `AppLocations` (a
/// wiring never imports another wiring).
final List<GoRoute> _standIns = [
  GoRoute(
    path: '/characters/:id',
    builder: (context, state) => Text(
      'character ${state.pathParameters['id']}',
      key: const Key('stand-in.character'),
    ),
  ),
  GoRoute(
    path: '/comics/:id',
    builder: (context, state) => Text(
      'comic ${state.pathParameters['id']}',
      key: const Key('stand-in.comic'),
    ),
  ),
];

/// Every [GoRoute] under [routes], depth first.
Iterable<GoRoute> _goRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
    }
    yield* _goRoutes(route.routes);
  }
}

/// The test root plus the router wiring and the discovery navigators.
Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = '/search',
}) async {
  final session = McTestSession.current;
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [
      RouterDIInitializer(ref),
      const DiscoveryNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) =>
            getIt.registerSingleton<DiscoveryRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [...discoveryRoutes, ..._standIns],
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
  mcTestWidgets('T-0046-AC5 the search route builds the search flow with no '
      'query', (tester) async {
    final router = await _boot(tester, initial: AppLocations.search());

    expect(router.state.uri.toString(), '/search');
    expect(find.text('fake search (none)'), findsOneWidget);
  });

  for (final query in ['spi', 'Spire Warden', 'a&b=c #1', 'Ünïcödé']) {
    mcTestWidgets('T-0046-AC5 /search?q= hands the query "$query" to the '
        'flow', (tester) async {
      final router = await _boot(tester, initial: AppLocations.search(query));

      expect(router.state.uri.queryParameters['q'], query);
      expect(find.text('fake search $query'), findsOneWidget);
    });
  }

  mcTestWidgets('T-0046-AC5 the link form miniclient://app/search?q=spi '
      'normalises to the search route', (tester) async {
    final link = PendingLinks.normalise('miniclient://app/search?q=spi');
    expect(link, AppLocations.search('spi'));
    await _boot(tester, initial: link);

    expect(find.text('fake search spi'), findsOneWidget);
  });

  mcTestWidgets('T-0046-AC3 openCharacter pushes the character location, and '
      'Back returns to the search', (tester) async {
    final router = await _boot(tester, initial: AppLocations.search('spi'));

    diContainer<DiscoverySearchNavigator>().openCharacter(
      const CharacterId(100480),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.character(100480));
    expect(find.text('character 100480'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake search spi'), findsOneWidget);
  });

  mcTestWidgets('T-0046-AC3 openComic pushes the comic location, and Back '
      'returns to the search', (tester) async {
    final router = await _boot(tester, initial: AppLocations.search('spi'));

    diContainer<DiscoverySearchNavigator>().openComic(const ComicId(501500));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(501500));
    expect(find.text('comic 501500'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake search spi'), findsOneWidget);
  });

  mcTestWidgets('T-0046-AC5 the wiring initializer registers the navigator '
      'and route targets that build the real flow', (tester) async {
    final ref = RouterRef();
    await McTestContainer.initialize(
      McTestSession.current,
      wirings: [RouterDIInitializer(ref), const DiscoveryWiringDIInitializer()],
    );
    final router = ref.attach(GoRouter(routes: discoveryRoutes));
    addTearDown(router.dispose);

    final targets = diContainer<DiscoveryRouteTargets>();
    final flow = targets.search(query: 'spi');
    expect(flow.initialQuery, 'spi');
    expect(flow.navigator, same(diContainer<DiscoverySearchNavigator>()));
    expect(targets.search().initialQuery, isNull);
  });

  test('T-0046-AC5 every AppLocations entry of the group equals its typed '
      'route', () {
    final drift = <String, ({String location, String route})>{
      'search()': (
        location: AppLocations.search(),
        route: const SearchRoute().location,
      ),
      for (final q in ['spi', '', 'Spire Warden', 'a&b=c #1', 'Ünïcödé'])
        'search($q)': (
          location: AppLocations.search(q),
          route: SearchRoute(q: q).location,
        ),
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above, or (a
    // route only this group reaches) to the list below.
    const groupOnly = <String>{};
    expect(
      {for (final r in _goRoutes(discoveryRoutes)) r.path},
      {'/search', ...groupOnly},
    );
    expect(_goRoutes(discoveryRoutes), hasLength(1 + groupOnly.length));
  });
}
