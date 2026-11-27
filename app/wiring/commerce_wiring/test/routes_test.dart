import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:commerce_wiring/commerce_wiring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:store_home/store_home.dart';

/// Stands in for the real store (which needs the commerce backend), so the
/// test is about the wiring. It shows which category the route asked for.
class _FakeStore extends StoreHomeFlow {
  const _FakeStore({
    required super.navigator,
    required super.clock,
    super.initialCategory,
  });

  @override
  Widget build(BuildContext context) => Text(
    'fake store ${initialCategory?.value ?? '(home)'}',
    key: const Key('fake.store'),
  );
}

class _Targets implements CommerceRouteTargets {
  @override
  StoreHomeFlow store({String? category}) => _FakeStore(
    navigator: diContainer<StoreHomeNavigator>(),
    clock: DateTime.now,
    initialCategory: category == null ? null : CategoryId(category),
  );

  @override
  CartPlaceholderFlow cart() => const CartPlaceholderFlow();
}

/// Other groups' routes the navigator reaches through `AppLocations` (a
/// wiring never imports another wiring).
final List<GoRoute> _standIns = [
  GoRoute(
    path: '/comics/:id',
    builder: (context, state) => Text(
      'comic ${state.pathParameters['id']}',
      key: const Key('stand-in.comic'),
    ),
  ),
  GoRoute(
    path: '/search',
    builder: (context, state) => Text(
      'search ${state.uri.queryParameters['q']}',
      key: const Key('stand-in.search'),
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

/// The test root plus the router wiring and the commerce navigators.
Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = '/store',
}) async {
  final session = McTestSession.current;
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [
      RouterDIInitializer(ref),
      const CommerceNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) => getIt.registerSingleton<CommerceRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [...commerceRoutes, ..._standIns, standInSignInRoute()],
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
  setUpAll(() {
    commerceFixtureSets.forEach(McFixtureSets.register);
    identityFixtureSets.forEach(McFixtureSets.register);
  });

  mcTestWidgets('T-0056-AC5 /store builds the store flow at its home', (
    tester,
  ) async {
    final router = await _boot(tester, initial: AppLocations.store);

    expect(router.state.uri.toString(), '/store');
    expect(find.text('fake store (home)'), findsOneWidget);
  });

  for (final id in ['heroes', 'team-ups', 'nope']) {
    mcTestWidgets('T-0056-AC5 /store/categories/$id opens the flow at that '
        'category', (tester) async {
      final router = await _boot(
        tester,
        initial: AppLocations.storeCategory(id),
      );

      expect(router.state.pathParameters['id'], id);
      expect(find.text('fake store $id'), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'the store is below it');
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('fake store (home)'), findsOneWidget);
    });
  }

  mcTestWidgets('T-0056-AC5 the link forms normalise to the store routes', (
    tester,
  ) async {
    expect(
      PendingLinks.normalise('miniclient://app/store'),
      AppLocations.store,
    );
    final link = PendingLinks.normalise(
      'miniclient://app/store/categories/cosmic',
    );
    expect(link, AppLocations.storeCategory('cosmic'));
    await _boot(tester, initial: link);

    expect(find.text('fake store cosmic'), findsOneWidget);
  });

  mcTestWidgets('T-0056-AC3 openComic pushes the comic location, and Back '
      'returns to the store', (tester) async {
    final router = await _boot(tester);

    diContainer<StoreHomeNavigator>().openComic(const ComicId(501501));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.comic(501501));
    expect(find.text('comic 501501'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake store (home)'), findsOneWidget);
  });

  mcTestWidgets('T-0056-AC3 openSearch pushes the search location with the '
      'query', (tester) async {
    final router = await _boot(tester);

    diContainer<StoreHomeNavigator>().openSearch('amber & co');
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.search('amber & co'));
    expect(find.text('search amber & co'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake store (home)'), findsOneWidget);
  });

  mcTestWidgets('T-0056-AC3 openCart pushes the cart placeholder, and Back '
      'returns to the store', (tester) async {
    final router = await _boot(tester);

    diContainer<StoreHomeNavigator>().openCart();
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), const StoreCartRoute().location);
    expect(find.byKey(const Key('cart.placeholder')), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake store (home)'), findsOneWidget);
  });

  mcTestWidgets('T-0056-AC3 requestSignIn: signed in it answers true at '
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

    final answer = await diContainer<StoreHomeNavigator>().requestSignIn();
    expect(answer, isTrue);
    expect(find.byKey(standInSignInKey), findsNothing);
  });

  mcTestWidgets('T-0056-AC3 requestSignIn: signed out it opens the sign-in '
      'screen for the cart, and Not now answers false', (tester) async {
    await _boot(tester);

    var answered = false;
    bool? answer;
    final pending = diContainer<StoreHomeNavigator>().requestSignIn().then((a) {
      answered = true;
      answer = a;
    });
    await tester.pumpAndSettle();
    expect(find.text(standInSignInText('cart')), findsOneWidget);
    expect(answered, isFalse);

    await tester.tap(find.byKey(standInSignInNotNowKey));
    await tester.pumpAndSettle();
    await pending;
    expect(answer, isFalse);
  });

  mcTestWidgets('T-0056-AC5 the wiring initializer registers the navigator '
      'and route targets that build the real flow, on the backend clock', (
    tester,
  ) async {
    final ref = RouterRef();
    await McTestContainer.initialize(
      McTestSession.current,
      wirings: [RouterDIInitializer(ref), const CommerceWiringDIInitializer()],
    );
    final router = ref.attach(GoRouter(routes: commerceRoutes));
    addTearDown(router.dispose);

    final targets = diContainer<CommerceRouteTargets>();
    final flow = targets.store(category: 'heroes');
    expect(flow.initialCategory, const CategoryId('heroes'));
    expect(flow.navigator, same(diContainer<StoreHomeNavigator>()));
    expect(flow.clock(), defaultMockClock, reason: "the backend's clock");
    expect(targets.store().initialCategory, isNull);
    expect(targets.cart(), isA<CartPlaceholderFlow>());
  });

  test('T-0056-AC5 without a mocked backend the store counts down against '
      'the device time', () {
    final clock = commerceClock(GetIt.asNewInstance());
    final before = DateTime.now();
    final now = clock();
    expect(now.isBefore(before), isFalse);
    expect(now.difference(before), lessThan(const Duration(minutes: 1)));
  });

  test('T-0056-AC5 every AppLocations entry of the group equals its typed '
      'route', () {
    final drift = <String, ({String location, String route})>{
      'store': (
        location: AppLocations.store,
        route: const StoreRoute().location,
      ),
      for (final id in ['heroes', 'team-ups', 'a b', 'Ünï/c'])
        'storeCategory($id)': (
          location: AppLocations.storeCategory(id),
          route: StoreCategoryRoute(id: id).location,
        ),
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above, or (a
    // route only this group reaches) to the list below.
    const groupOnly = <String>{'cart'};
    expect(
      {for (final r in _goRoutes(commerceRoutes)) r.path},
      {'/store', 'categories/:id', ...groupOnly},
    );
    expect(
      {for (final r in _goRoutes(commerceRoutes)) r.name},
      {'store_home', 'store_category', 'store_cart'},
    );
  });
}
