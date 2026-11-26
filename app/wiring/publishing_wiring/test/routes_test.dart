import 'package:app_core/app_core.dart';
import 'package:comics_details/comics_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:publishing_wiring/publishing_wiring.dart';

/// Stands in for the real comic page (which needs the comics backend), so
/// the test is about the wiring. It shows which id the route asked for.
class _FakeComic extends ComicsDetailsFlow {
  const _FakeComic({required super.navigator, required super.comicId});

  @override
  Widget build(BuildContext context) =>
      Text('fake comic ${comicId.value}', key: const Key('fake.comic'));
}

class _Targets implements PublishingRouteTargets {
  @override
  ComicsDetailsFlow comicDetails(int id) => _FakeComic(
    navigator: diContainer<ComicsDetailsNavigator>(),
    comicId: ComicId(id),
  );

  @override
  CreatorDetailsPlaceholderFlow creatorDetails(int id) =>
      CreatorDetailsPlaceholderFlow(id: id);
}

/// Another group's route the navigator reaches through `AppLocations`
/// (universe_wiring owns it; a wiring never imports another wiring).
final GoRoute _charactersStandIn = GoRoute(
  path: '/characters/:id',
  builder: (context, state) => Text(
    'character ${state.pathParameters['id']}',
    key: const Key('stand-in.character'),
  ),
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

/// The test root plus the router wiring and the publishing navigators, over
/// the session's strict backend (identity routes served).
Future<GoRouter> _boot(
  WidgetTester tester, {
  String initial = '/comics/7',
}) async {
  final session = McTestSession.current
    ..backend.useFixtureSet('identity.default');
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [
      RouterDIInitializer(ref),
      const PublishingNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) =>
            getIt.registerSingleton<PublishingRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [...publishingRoutes, _charactersStandIn],
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

/// Lets the session's real file write finish (F-0038), then settles.
Future<void> _settleRealIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (find.byKey(fixtureSignInSheetKey).evaluate().isEmpty) {
      return;
    }
  }
}

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets('T-0041-AC5 the comic route builds the comic flow for its id', (
    tester,
  ) async {
    final router = await _boot(tester, initial: AppLocations.comic(501500));

    expect(router.state.uri.toString(), '/comics/501500');
    expect(find.text('fake comic 501500'), findsOneWidget);
  });

  mcTestWidgets('T-0041-AC3 openCharacter pushes the characters placeholder '
      'location', (tester) async {
    final router = await _boot(tester);

    diContainer<ComicsDetailsNavigator>().openCharacter(
      const CharacterId(100366),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.character(100366));
    expect(find.text('character 100366'), findsOneWidget);
    // A push: the comic stays below, so Back returns to it.
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('fake comic 7'), findsOneWidget);
  });

  mcTestWidgets('T-0041-AC3 openCreator pushes CreatorDetailsRoute and the '
      'placeholder shows the id', (tester) async {
    final router = await _boot(tester);

    diContainer<ComicsDetailsNavigator>().openCreator(const CreatorId(300016));
    await tester.pumpAndSettle();

    expect(
      router.state.uri.toString(),
      const CreatorDetailsRoute(id: 300016).location,
    );
    expect(find.text('Creator details 300016'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  mcTestWidgets('T-0041-AC6 requestSignIn: Sign in on the sheet signs the '
      'fixture user in and answers true', (tester) async {
    await _boot(tester);
    final reader = diContainer<SessionReader>();
    expect(reader.isSignedIn, isFalse);

    final answer = diContainer<ComicsDetailsNavigator>().requestSignIn();
    await tester.pumpAndSettle();
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);
    expect(find.textContaining(fixtureUsers.first.email), findsOneWidget);

    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await _settleRealIo(tester);

    expect(await answer, isTrue);
    expect(reader.userId, fixtureUsers.first.id);
    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
  });

  mcTestWidgets('T-0041-AC6 requestSignIn: Not now answers false and leaves '
      'the user signed out', (tester) async {
    await _boot(tester);

    final answer = diContainer<ComicsDetailsNavigator>().requestSignIn();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInCancelKey));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
    expect(
      McTestSession.current.backend.requests.where(
        (r) => r.path.startsWith('/v1/auth/'),
      ),
      isEmpty,
    );
  });

  mcTestWidgets('T-0041-AC6 requestSignIn: dismissing the sheet answers '
      'false', (tester) async {
    await _boot(tester);

    final answer = diContainer<ComicsDetailsNavigator>().requestSignIn();
    await tester.pumpAndSettle();
    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
  });

  mcTestWidgets('T-0041-AC6 requestSignIn: a failed sign-in keeps the sheet '
      'open with an error', (tester) async {
    await _boot(tester);
    McTestSession.current.backend.fail(
      'POST /v1/auth/sign-in',
      BackendFailure.serverError,
    );

    final answer = diContainer<ComicsDetailsNavigator>().requestSignIn();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Signing in failed. Please try again.'), findsOneWidget);
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);
    await tester.tap(find.byKey(fixtureSignInCancelKey));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  mcTestWidgets('T-0041-AC6 requestSignIn: already signed in answers true '
      'without a sheet', (tester) async {
    await _boot(tester);
    final user = fixtureUsers.first;
    await tester.runAsync(
      () => diContainer<SessionWriter>().signIn(
        userId: user.id,
        tokens: AuthTokens(
          accessToken: mintAccessToken(user.id, 1),
          refreshToken: mintRefreshToken(user.id, 1),
        ),
      ),
    );

    final answer = diContainer<ComicsDetailsNavigator>().requestSignIn();
    await tester.pumpAndSettle();

    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
    expect(await answer, isTrue);
  });

  test('T-0041-AC6 requestSignIn before the router shows anything answers '
      'false', () async {
    await resetDIContainer();
    addTearDown(resetDIContainer);
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      McDIInitializer((getIt, _) {
        getIt
          ..registerSingleton<SessionReader>(_SignedOut())
          ..registerSingleton<AuthApi>(_NoAuth());
      }),
      const PublishingNavigatorsDIInitializer(),
    ]);
    final router = ref.attach(GoRouter(routes: publishingRoutes));
    addTearDown(router.dispose);

    expect(
      await diContainer<ComicsDetailsNavigator>().requestSignIn(),
      isFalse,
    );
  });

  test('T-0041-AC5 the wiring initializer resolves the route targets and the '
      'navigator', () async {
    await resetDIContainer();
    addTearDown(resetDIContainer);
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      McDIInitializer((getIt, _) {
        getIt
          ..registerSingleton<SessionReader>(_SignedOut())
          ..registerSingleton<AuthApi>(_NoAuth());
      }),
      const PublishingWiringDIInitializer(),
    ]);
    final router = ref.attach(GoRouter(routes: publishingRoutes));
    addTearDown(router.dispose);

    final flow = diContainer<PublishingRouteTargets>().comicDetails(501500);
    expect(flow.comicId, const ComicId(501500));
    expect(flow.navigator, same(diContainer<ComicsDetailsNavigator>()));
    expect(
      diContainer<PublishingRouteTargets>().creatorDetails(3).id,
      3,
    );
  });

  test('T-0041-AC5 every AppLocations entry of the group equals its typed '
      'route', () {
    final drift = <String, ({String location, String route})>{
      'comic(7)': (
        location: AppLocations.comic(7),
        route: const ComicDetailsRoute(id: 7).location,
      ),
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above, or (a
    // route only this group reaches) to the list below.
    const groupOnly = {'/creators/:id'};
    expect(
      {for (final r in _goRoutes(publishingRoutes)) r.path},
      {'/comics/:id', ...groupOnly},
    );
    expect(
      _goRoutes(publishingRoutes),
      hasLength(drift.length + groupOnly.length),
    );
  });
}

class _SignedOut implements SessionReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isSignedIn => false;
}

class _NoAuth implements AuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
