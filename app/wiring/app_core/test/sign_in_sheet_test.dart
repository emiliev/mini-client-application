// T-0048: the temporary fixture sign-in sheet, now shared by every wiring
// whose navigator implements `requestSignIn()` (publishing, library). The
// behaviour T-0041 pinned in publishing_wiring is pinned here on the shared
// function itself; publishing_wiring keeps its own tests through its
// navigator.
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _reason = 'to test the sheet';

/// The test root plus the router wiring, over the session's strict backend
/// (identity routes served), and a router showing one page.
Future<RouterRef> _boot(WidgetTester tester) async {
  final session = McTestSession.current
    ..backend.useFixtureSet('identity.default');
  final ref = RouterRef();
  await McTestContainer.initialize(
    session,
    wirings: [RouterDIInitializer(ref)],
  );
  final router = ref.attach(
    GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home', key: Key('home')),
        ),
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
  return ref;
}

Future<bool> _request(RouterRef ref) => requestFixtureSignIn(
  routerRef: ref,
  session: diContainer<SessionReader>(),
  auth: diContainer<AuthApi>(),
  reason: _reason,
);

/// Lets the session's real file write finish (F-0038), then settles: until
/// the sheet closed, or [rounds] rounds when given.
Future<void> _settleRealIo(WidgetTester tester, {int? rounds}) async {
  for (var i = 0; i < (rounds ?? 20); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (rounds == null &&
        find.byKey(fixtureSignInSheetKey).evaluate().isEmpty) {
      return;
    }
  }
}

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: Sign in signs the fixture '
      'user in, says why, and answers true', (tester) async {
    final ref = await _boot(tester);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);

    final answer = _request(ref);
    await tester.pumpAndSettle();
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);
    expect(
      find.text(
        'Sign in as ${fixtureUsers.first.displayName} '
        '(${fixtureUsers.first.email}) $_reason.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await _settleRealIo(tester);

    expect(await answer, isTrue);
    expect(diContainer<SessionReader>().userId, fixtureUsers.first.id);
    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: while signing in, the '
      'barrier, Back, Not now and a drag do not close the sheet', (
    tester,
  ) async {
    final ref = await _boot(tester);
    final backend = McTestSession.current.backend
      ..hold('POST /v1/auth/sign-in');

    final answer = _request(ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await tester.pump();
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);
    final notNow = find.descendant(
      of: find.byKey(fixtureSignInCancelKey),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(notNow).enabled, isFalse);
    await tester.drag(find.byKey(fixtureSignInSheetKey), const Offset(0, 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(fixtureSignInSheetKey), findsOneWidget);

    await backend.release('POST /v1/auth/sign-in');
    await _settleRealIo(tester);

    expect(await answer, isTrue);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: idle, a drag down '
      'dismisses the sheet and answers false', (tester) async {
    final ref = await _boot(tester);

    final answer = _request(ref);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(fixtureSignInSheetKey), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
    expect(await answer, isFalse);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: a sheet closed while '
      'signing in answers the real outcome', (tester) async {
    final ref = await _boot(tester);
    final backend = McTestSession.current.backend
      ..hold('POST /v1/auth/sign-in');

    final answer = _request(ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await tester.pump();
    Navigator.of(tester.element(find.byKey(fixtureSignInSheetKey))).pop();
    await tester.pumpAndSettle();

    await backend.release('POST /v1/auth/sign-in');
    await _settleRealIo(tester, rounds: 20);

    expect(await answer, isTrue);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: Not now answers false and '
      'sends nothing', (tester) async {
    final ref = await _boot(tester);

    final answer = _request(ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInCancelKey));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    expect(McTestSession.current.backend.requests, isEmpty);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: a failed sign-in keeps the '
      'sheet open with an error', (tester) async {
    final ref = await _boot(tester);
    McTestSession.current.backend.fail(
      'POST /v1/auth/sign-in',
      BackendFailure.serverError,
    );

    final answer = _request(ref);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(fixtureSignInButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Signing in failed. Please try again.'), findsOneWidget);
    await tester.tap(find.byKey(fixtureSignInCancelKey));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  mcTestWidgets('T-0048-AC6 requestFixtureSignIn: already signed in answers '
      'true without a sheet', (tester) async {
    final ref = await _boot(tester);
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

    final answer = _request(ref);
    await tester.pumpAndSettle();

    expect(find.byKey(fixtureSignInSheetKey), findsNothing);
    expect(await answer, isTrue);
  });

  test('T-0048-AC6 requestFixtureSignIn before the router shows anything '
      'answers false', () async {
    final ref = RouterRef();
    final router = ref.attach(
      GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      ),
    );
    addTearDown(router.dispose);

    expect(
      await requestFixtureSignIn(
        routerRef: ref,
        session: _SignedOut(),
        auth: _NoAuth(),
        reason: _reason,
      ),
      isFalse,
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
