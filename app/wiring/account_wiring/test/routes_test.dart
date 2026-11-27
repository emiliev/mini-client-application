import 'dart:async';

import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// Stands in for the real screen, so the test is about the wiring.
class _FakeSettings extends SettingsAppearanceFlow {
  const _FakeSettings({required super.navigator});

  @override
  Widget build(BuildContext context) =>
      const Text('fake appearance', key: Key('fake.appearance'));
}

class _Targets implements AccountRouteTargets {
  @override
  SettingsAppearanceFlow settingsAppearance() =>
      _FakeSettings(navigator: diContainer<SettingsAppearanceNavigator>());
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

/// The test root plus the router wiring and the account navigators, with
/// the routes nested under a stand-in home as the app nests them.
Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = AppLocations.settingsAppearance,
}) async {
  final ref = RouterRef();
  await McTestContainer.initialize(
    McTestSession.current,
    wirings: [
      RouterDIInitializer(ref),
      const AccountNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) => getIt.registerSingleton<AccountRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: nestUnderHome(
        [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Text('home', key: Key('stand-in.home')),
          ),
        ],
        accountRoutes,
      ),
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

  mcTestWidgets('T-0063-AC3 /settings/appearance builds the appearance flow, '
      'with home below it', (tester) async {
    final router = await _boot(tester);

    expect(router.state.uri.toString(), '/settings/appearance');
    expect(router.state.name, 'settings_appearance');
    expect(find.text('fake appearance'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'home is below it');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
  });

  mcTestWidgets('T-0063-AC3 the link form normalises to the route, and the '
      'location is pushed from home', (tester) async {
    expect(
      PendingLinks.normalise('miniclient://app/settings/appearance'),
      AppLocations.settingsAppearance,
    );
    final router = await _boot(tester, initial: '/');
    unawaited(router.push(AppLocations.settingsAppearance));
    await tester.pumpAndSettle();
    expect(find.text('fake appearance'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
  });

  mcTestWidgets('T-0063-AC3 requestSignIn: signed in it answers true at '
      'once, with no sheet', (tester) async {
    McTestSession.current.backend.useFixtureSet('identity.default');
    await _boot(tester);
    final user = fixtureUsers.first;
    await tester.runAsync(
      () => diContainer<AuthApi>().signIn(
        email: user.email,
        password: user.password,
      ),
    );

    final answer = await diContainer<SettingsAppearanceNavigator>()
        .requestSignIn();
    expect(answer, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  mcTestWidgets('T-0063-AC3 requestSignIn: signed out it shows the shared '
      'sheet with the sync reason, and Cancel answers false', (tester) async {
    await _boot(tester);

    var answered = false;
    bool? answer;
    final pending = diContainer<SettingsAppearanceNavigator>()
        .requestSignIn()
        .then((a) {
          answered = true;
          answer = a;
        });
    await tester.pumpAndSettle();
    expect(
      find.textContaining('to sync your appearance across devices'),
      findsOneWidget,
    );
    expect(answered, isFalse);

    await tester.tap(find.byKey(fixtureSignInCancelKey));
    await tester.pumpAndSettle();
    await pending;
    expect(answer, isFalse);
  });

  mcTestWidgets('T-0063-AC3 requestSignIn: signing in on the sheet answers '
      'true', (tester) async {
    McTestSession.current.backend.useFixtureSet('identity.default');
    await _boot(tester);

    bool? answer;
    final pending = diContainer<SettingsAppearanceNavigator>()
        .requestSignIn()
        .then((a) => answer = a);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInButtonKey));
    for (var i = 0; i < 20 && answer == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
    await pending;
    expect(answer, isTrue);
  });

  mcTestWidgets('T-0063-AC3 the wiring initializer registers the navigator '
      'and route targets that build the real flow', (tester) async {
    final ref = RouterRef();
    await McTestContainer.initialize(
      McTestSession.current,
      wirings: [RouterDIInitializer(ref), const AccountWiringDIInitializer()],
    );
    final router = ref.attach(GoRouter(routes: accountRoutes));
    addTearDown(router.dispose);

    final flow = diContainer<AccountRouteTargets>().settingsAppearance();
    expect(flow.navigator, same(diContainer<SettingsAppearanceNavigator>()));
  });

  test('T-0063-AC3 every AppLocations entry of the group equals its typed '
      'route', () {
    expect(
      AppLocations.settingsAppearance,
      const SettingsAppearanceRoute().location,
    );
    // A new route in the wiring must be added above.
    expect(
      {for (final r in _goRoutes(accountRoutes)) r.path},
      {'/settings/appearance'},
    );
    expect(
      {for (final r in _goRoutes(accountRoutes)) r.name},
      {'settings_appearance'},
    );
  });
}
