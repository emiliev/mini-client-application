import 'package:app_core/app_core.dart';
import 'package:app_core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:library_wiring/library_wiring.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _finish = Key('fake.editor.finish');
const _leave = Key('fake.editor.leave');

/// Stands in for the real editor (which needs the library backend), so the
/// test is about the wiring: it shows which list the route asked for and
/// ends the flow with a result, as the editor does.
class _FakeEditor extends ReadingListEditorFlow {
  const _FakeEditor({
    required super.navigator,
    required super.onComplete,
    super.editing,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('fake editor ${editing?.value ?? 'new'}'),
      TextButton(
        key: _finish,
        onPressed: () => onComplete(editing ?? const ReadingListId('l-9')),
        child: const Text('finish'),
      ),
      TextButton(
        key: _leave,
        onPressed: () => onComplete(null),
        child: const Text('leave'),
      ),
    ],
  );
}

/// Route targets over the fake editor, mapping its result as the real
/// targets do (through the real implementation's contract: the route gets
/// the app-level `String`).
class _Targets implements LibraryRouteTargets {
  @override
  ReadingListEditorFlow newReadingList({
    required ValueChanged<String?> onComplete,
  }) => _FakeEditor(
    navigator: diContainer<ReadingListEditorNavigator>(),
    onComplete: (id) => onComplete(id?.value),
  );

  @override
  ReadingListEditorFlow editReadingList(
    String id, {
    required ValueChanged<String?> onComplete,
  }) => _FakeEditor(
    navigator: diContainer<ReadingListEditorNavigator>(),
    editing: ReadingListId(id),
    onComplete: (saved) => onComplete(saved?.value),
  );
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

/// The test root plus the router wiring and the library navigators, over the
/// session's strict backend (identity routes served), with a home below the
/// editor routes (as the app's).
Future<GoRouter> _boot(WidgetTester tester, {String initial = '/'}) async {
  final session = McTestSession.current
    ..backend.useFixtureSet('identity.default');
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [
      RouterDIInitializer(ref),
      const LibraryNavigatorsDIInitializer(),
      McDIInitializer(
        (getIt, _) => getIt.registerSingleton<LibraryRouteTargets>(_Targets()),
      ),
    ],
  );
  final router = ref.attach(
    GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home', key: Key('home')),
        ),
        ...libraryRoutes,
        standInSignInRoute(signIn: _signInFixtureUser),
      ],
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
}

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets('T-0048-AC6 the wiring returns the new list id to the caller '
      'that awaits AppFlows.createReadingList', (tester) async {
    final router = await _boot(tester);

    final result = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/me/lists/new');
    expect(find.text('fake editor new'), findsOneWidget);
    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(await result, 'l-9');
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  mcTestWidgets('T-0048-AC3 the edit route builds the editor for its id and '
      'returns that id', (tester) async {
    final router = await _boot(tester);

    final result = AppFlows.editReadingList(router, 'l-1');
    await tester.pumpAndSettle();
    expect(find.text('fake editor l-1'), findsOneWidget);
    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(await result, 'l-1');
  });

  mcTestWidgets('T-0048-AC6 an editor that ends without a list gives the '
      'caller null', (tester) async {
    final router = await _boot(tester);

    final result = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_leave));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  mcTestWidgets('T-0048-AC5 the deep link /me/lists/new opens the editor, '
      'and finishing it goes home', (tester) async {
    final router = await _boot(tester, initial: AppLocations.newReadingList);
    expect(find.text('fake editor new'), findsOneWidget);

    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.home);
  });

  mcTestWidgets(
    'T-0066-AC3 requestSignIn: the reading list editor signs in on the screen '
    'and gets true only once a session exists',
    (tester) async {
      await _boot(tester);
      final reader = diContainer<SessionReader>();
      expect(reader.isSignedIn, isFalse);

      bool? answer;
      final pending = diContainer<ReadingListEditorNavigator>()
          .requestSignIn()
          .then(
            (a) => answer = a,
          );
      await tester.pumpAndSettle();
      expect(find.text(standInSignInText('readingLists')), findsOneWidget);
      expect(answer, isNull, reason: 'the caller waits');

      await tester.tap(find.byKey(standInSignInConfirmKey));
      await _settleRealIo(tester);
      await pending;

      expect(answer, isTrue);
      expect(reader.userId, fixtureUsers.first.id);
    },
  );

  mcTestWidgets(
    'T-0048-AC6 T-0066-AC3 requestSignIn opens the sign-in screen for the '
    "reading lists, and answers its outcome (T-0066)",
    (tester) async {
      await _boot(tester);

      final answer = diContainer<ReadingListEditorNavigator>().requestSignIn();
      await tester.pumpAndSettle();
      expect(find.byKey(standInSignInKey), findsOneWidget);
      expect(find.text(standInSignInText('readingLists')), findsOneWidget);
      await tester.tap(find.byKey(standInSignInNotNowKey));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    },
  );

  mcTestWidgets(
    'T-0048-AC6 T-0066-AC3 requestSignIn: signed in answers true without a '
    'sign-in screen',
    (tester) async {
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

      final answer = diContainer<ReadingListEditorNavigator>().requestSignIn();
      await tester.pumpAndSettle();

      expect(find.byKey(standInSignInKey), findsNothing);
      expect(await answer, isTrue);
    },
  );

  test('T-0048-AC6 the wiring initializer resolves the route targets, whose '
      "flows carry the navigator and map the feature's result", () async {
    await resetDIContainer();
    addTearDown(resetDIContainer);
    final ref = RouterRef();
    await initializeDIContainer([
      RouterDIInitializer(ref),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<SessionReader>(_SignedOut());
      }),
      const LibraryWiringDIInitializer(),
    ]);
    final router = ref.attach(GoRouter(routes: libraryRoutes));
    addTearDown(router.dispose);
    final targets = diContainer<LibraryRouteTargets>();
    final results = <String?>[];

    final created = targets.newReadingList(onComplete: results.add);
    expect(created.navigator, same(diContainer<ReadingListEditorNavigator>()));
    expect(created.editing, isNull);
    created.onComplete(const ReadingListId('l-5'));
    created.onComplete(null);

    final edited = targets.editReadingList('l-2', onComplete: results.add);
    expect(edited.editing, const ReadingListId('l-2'));
    expect(edited.navigator, same(created.navigator));
    edited.onComplete(const ReadingListId('l-2'));

    expect(results, ['l-5', null, 'l-2']);
    expect(
      await diContainer<ReadingListEditorNavigator>().requestSignIn(),
      isFalse,
    );
  });

  test('T-0048-AC5 every AppLocations entry of the group equals its typed '
      'route', () {
    final drift = <String, ({String location, String route})>{
      'newReadingList': (
        location: AppLocations.newReadingList,
        route: const NewReadingListRoute().location,
      ),
      "editReadingList('l-1')": (
        location: AppLocations.editReadingList('l-1'),
        route: const EditReadingListRoute(id: 'l-1').location,
      ),
      "editReadingList('a b')": (
        location: AppLocations.editReadingList('a b'),
        route: const EditReadingListRoute(id: 'a b').location,
      ),
    };

    for (final entry in drift.entries) {
      expect(entry.value.location, entry.value.route, reason: entry.key);
    }
    // A new route in the wiring must be added to the table above.
    expect(
      {for (final r in _goRoutes(libraryRoutes)) r.path},
      {'/me/lists/new', '/me/lists/:id/edit'},
    );
  });
}

class _SignedOut implements SessionReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isSignedIn => false;
}
