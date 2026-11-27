import 'dart:async';

import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:auth_signin/auth_signin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
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

  /// Not under test here: `_bootReal` runs the real sign-in route.
  @override
  AuthSignInFlow signIn({
    required ValueChanged<bool> onComplete,
    String? reason,
  }) => throw UnimplementedError();
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

/// The test root with the account wiring as the app registers it (the real
/// sign-in route and form, over the identity fixtures), with stand-ins for the
/// pages other groups own: home, and the protected target a guard would have
/// sent the user from. Routes nest under home as the app's do.
Future<GoRouter> _bootReal(
  WidgetTester tester, {
  String initial = '/',
}) async {
  McTestSession.current.backend.useFixtureSet('identity.default');
  final ref = RouterRef();
  await McTestContainer.initialize(
    McTestSession.current,
    wirings: [RouterDIInitializer(ref), const AccountWiringDIInitializer()],
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
        [
          ...accountRoutes,
          GoRoute(
            path: '/me/lists/new',
            builder: (context, state) =>
                const Text('target', key: Key('stand-in.target')),
          ),
        ],
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

/// Ends a step that sends the sign-in: the request on fake time, then the
/// session's real file save, then the screen settles (F-0038).
Future<void> _settleSignIn(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await mcFinishStorageIo(tester);
  await mcSettle(tester);
}

Future<void> _submitForm(WidgetTester tester) async {
  await tester.tap(find.byKey(McFormScaffold.submitKey));
  await _settleSignIn(tester);
}

/// Taps the demo account button for [email] (it fills the form).
Future<void> _useDemoAccount(WidgetTester tester, String email) async {
  await tester.tap(find.byKey(ValueKey<String>('auth_signin.demo.$email')));
  await tester.pump();
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

  mcTestWidgets(
    'T-0063-AC3 T-0066-AC3 requestSignIn: signed in it answers true at '
    'once, with no sign-in screen',
    (tester) async {
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
    },
  );

  mcTestWidgets(
    'T-0063-AC3 T-0066-AC3 requestSignIn: signed out it opens the sign-in '
    'screen for the sync, and Not now answers false (T-0066)',
    (
      tester,
    ) async {
      final router = await _bootReal(tester);

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
        router.state.uri.toString(),
        AppLocations.signIn(reason: SignInPurpose.appearanceSync),
      );
      expect(
        find.text('Sign in to sync your appearance across devices.'),
        findsOneWidget,
      );
      expect(answered, isFalse);

      await tester.tap(
        find.byKey(const ValueKey<String>('auth_signin.not_now')),
      );
      await tester.pumpAndSettle();
      await pending;
      expect(answer, isFalse);
      expect(diContainer<SessionReader>().isSignedIn, isFalse);
    },
  );

  mcTestWidgets(
    'T-0063-AC3 T-0066-AC3 requestSignIn: signing in on the form answers '
    'true',
    (tester) async {
      await _bootReal(tester);

      bool? answer;
      final pending = diContainer<SettingsAppearanceNavigator>()
          .requestSignIn()
          .then((a) => answer = a);
      await tester.pumpAndSettle();
      await _useDemoAccount(tester, fixtureUsers.first.email);
      await _submitForm(tester);
      await pending;

      expect(answer, isTrue);
      expect(diContainer<SessionReader>().userId, fixtureUsers.first.id);
      expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
    },
  );

  mcTestWidgets('T-0066-AC3 requestSignIn: leaving the form by Back while the '
      'request is on its way answers false, and the sign-in that lands is '
      'undone', (tester) async {
    await _bootReal(tester);
    final backend = McTestSession.current.backend
      ..hold('POST /v1/auth/sign-in');

    bool? answer;
    final pending = diContainer<SettingsAppearanceNavigator>()
        .requestSignIn()
        .then((a) => answer = a);
    await tester.pumpAndSettle();
    await _useDemoAccount(tester, fixtureUsers.first.email);
    await tester.tap(find.byKey(McFormScaffold.submitKey));
    await tester.pump();
    // A system back (the form has no back button while the request runs).
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await pending;
    expect(answer, isFalse);

    await backend.release('POST /v1/auth/sign-in');
    await _settleSignIn(tester);

    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
  });

  mcTestWidgets('T-0066-AC2 the real route: signing in with from goes there, '
      'with home below it', (tester) async {
    final router = await _bootReal(
      tester,
      initial: AppLocations.signIn(from: '/me/lists/new'),
    );
    expect(find.text('Use your Mini Client account.'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'home is below sign-in');

    await _useDemoAccount(tester, fixtureUsers.first.email);
    await _submitForm(tester);

    expect(find.byKey(const Key('stand-in.target')), findsOneWidget);
    expect(Uri.parse(router.state.uri.toString()).path, '/me/lists/new');
    expect(diContainer<SessionReader>().userId, fixtureUsers.first.id);
    expect(router.canPop(), isTrue, reason: 'the stack is [home, target]');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
  });

  for (final from in [
    'https://evil.com',
    '//evil.com',
    '/%2Fevil.com',
    '/auth/sign-in',
  ]) {
    mcTestWidgets('T-0066-AC2 the real route: a foreign from ($from) falls '
        'back to home', (tester) async {
      final router = await _bootReal(
        tester,
        initial: AppLocations.signIn(from: from),
      );

      await _useDemoAccount(tester, fixtureUsers.first.email);
      await _submitForm(tester);

      expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
      expect(Uri.parse(router.state.uri.toString()).path, '/');
      expect(diContainer<SessionReader>().isSignedIn, isTrue);
    });
  }

  mcTestWidgets('T-0066-AC2 the real route: Not now with from ends at home, '
      'signed out', (tester) async {
    await _bootReal(
      tester,
      initial: AppLocations.signIn(from: '/me/lists/new'),
    );

    await tester.tap(find.byKey(const ValueKey<String>('auth_signin.not_now')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stand-in.home')), findsOneWidget);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
  });

  mcTestWidgets('T-0066-AC1 the real route: a reason code names what the '
      'sign-in is for, and an unknown one says nothing', (tester) async {
    await _bootReal(
      tester,
      initial: AppLocations.signIn(reason: SignInPurpose.favourites),
    );
    expect(find.text('Sign in to keep your favourites.'), findsOneWidget);
  });

  mcTestWidgets('T-0066-AC1 the real route: an unknown reason code says '
      'nothing, and a link cannot put its own words on the screen', (
    tester,
  ) async {
    await _bootReal(tester, initial: '/auth/sign-in?reason=Call%20555-0100');
    expect(find.text('Use your Mini Client account.'), findsOneWidget);
    expect(find.textContaining('555'), findsNothing);
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
    // T-0066: the sign-in route, with and without its parameters.
    expect(AppLocations.signIn(), const SignInRoute().location);
    for (final from in [
      '/me/lists/new',
      '/library/shelf?tab=2#top',
      '/me/lists/a%2Fb/edit',
      'https://evil.com/?a=b&c',
    ]) {
      expect(
        AppLocations.signIn(from: from),
        SignInRoute(from: from).location,
        reason: from,
      );
      for (final purpose in SignInPurpose.values) {
        expect(
          AppLocations.signIn(from: from, reason: purpose),
          SignInRoute(from: from, reason: purpose.name).location,
        );
      }
    }
    // The purposes the app names are the codes the feature reads.
    expect(
      [for (final p in SignInPurpose.values) SignInReason.parse(p.name)],
      SignInReason.values,
    );
    expect(
      [for (final p in SignInPurpose.values) p.name],
      [for (final r in SignInReason.values) r.name],
    );
    // A new route in the wiring must be added above.
    expect(
      {for (final r in _goRoutes(accountRoutes)) r.path},
      {'/settings/appearance', '/auth/sign-in'},
    );
    expect(
      {for (final r in _goRoutes(accountRoutes)) r.name},
      {'settings_appearance', 'auth_sign_in'},
    );
  });
}
