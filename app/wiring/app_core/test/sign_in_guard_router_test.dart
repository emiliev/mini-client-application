// T-0066-AC2 and AC3: the real `SignInGuard` as the router's `redirect` and
// `refreshListenable`, with `AppFlows` and `requestAppSignIn`, over stand-in
// pages. Routes nest under a stand-in home as the app nests them, so a link
// opens `[home, target]`. The real sign-in route (account_wiring) and the
// real app router (mini_client) have their own tests; the sign-in page here
// does what that route does, in a few lines.
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_session/mc_session.dart';

const _home = Key('home');
const _editor = Key('editor');
const _signInPage = Key('sign_in.page');
const _signInButton = Key('sign_in.sign_in');
const _signInNowButton = Key('sign_in.sign_in_now');
const _notNowButton = Key('sign_in.not_now');
const _finishButton = Key('editor.finish');

final class _FakeSession implements SessionReader {
  _FakeSession({bool signedIn = false}) : _signedIn = signedIn;

  bool _signedIn;
  final StreamController<AuthStatus> changes =
      StreamController<AuthStatus>.broadcast();

  void signIn() {
    _signedIn = true;
    changes.add(AuthStatus.signedIn);
  }

  void signOut() {
    _signedIn = false;
    changes.add(AuthStatus.signedOut);
  }

  @override
  bool get isSignedIn => _signedIn;

  @override
  AuthStatus get status =>
      _signedIn ? AuthStatus.signedIn : AuthStatus.signedOut;

  @override
  Stream<AuthStatus> get authState => changes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What `SignInRoute` (account_wiring) does with the form's result: with a
/// `from`, go there; else answer the caller.
Widget _signInPageFor(
  BuildContext context,
  GoRouterState state,
  _FakeSession session,
) {
  final router = GoRouter.of(context);
  final from = state.uri.queryParameters['from'];
  return FlowResultRoute<bool>(
    extra: state.extra,
    builder: (complete) => Column(
      key: _signInPage,
      children: [
        TextButton(
          key: _signInButton,
          onPressed: () {
            // The session changes first, and the answer comes later, as it
            // does in the app (the session is saved before the sign-in
            // returns): a re-parse that started with the session change has
            // finished by then.
            session.signIn();
            Timer(const Duration(milliseconds: 10), () {
              if (from != null) {
                router.go(safeSignInTarget(from));
              } else {
                complete(true);
              }
            });
          },
          child: const Text('sign in'),
        ),
        TextButton(
          key: _signInNowButton,
          // The session changes and the answer comes in the same turn.
          onPressed: () {
            session.signIn();
            if (from != null) {
              router.go(safeSignInTarget(from));
            } else {
              complete(true);
            }
          },
          child: const Text('sign in now'),
        ),
        TextButton(
          key: _notNowButton,
          onPressed: () => complete(false),
          child: const Text('not now'),
        ),
      ],
    ),
  );
}

class _App {
  _App(this.router, this.session);

  final GoRouter router;
  final _FakeSession session;

  /// What the callers of `createReadingList` and `editReadingList` got.
  final List<String> got = [];

  /// Opens the editor as a flow caller does (a push).
  void create() => unawaited(
    AppFlows.createReadingList(router).then((v) => got.add('c:$v')),
  );

  void edit(String id) => unawaited(
    AppFlows.editReadingList(router, id).then((v) => got.add('e:$id:$v')),
  );

  /// The location on screen: a pushed page's own, else the router's.
  String get location {
    final last = router.routerDelegate.currentConfiguration.last;
    return last is ImperativeRouteMatch
        ? last.matches.uri.toString()
        : router.routerDelegate.currentConfiguration.uri.toString();
  }
}

Future<_App> _app(
  WidgetTester tester, {
  bool signedIn = true,
  String initial = '/',
}) async {
  final session = _FakeSession(signedIn: signedIn);
  addTearDown(session.changes.close);
  final guard = SignInGuard(session);
  final router = GoRouter(
    initialLocation: initial,
    refreshListenable: guard.refresh,
    redirect: (context, state) => guard.redirect(state.uri),
    routes: nestUnderHome(
      [
        GoRoute(
          path: '/',
          builder: (context, s) => const Text('home', key: _home),
        ),
      ],
      [
        GoRoute(
          path: '/auth/sign-in',
          builder: (context, s) => _signInPageFor(context, s, session),
        ),
        GoRoute(
          path: AppLocations.newReadingList,
          builder: (context, s) => FlowResultRoute<String>(
            extra: s.extra,
            builder: (complete) => TextButton(
              key: _finishButton,
              onPressed: () => complete('l-9'),
              child: const Text('editor'),
            ),
          ),
        ),
        GoRoute(
          path: '/me/lists/:id/edit',
          builder: (context, s) => FlowResultRoute<String>(
            extra: s.extra,
            builder: (complete) => TextButton(
              key: _editor,
              onPressed: () => complete(s.pathParameters['id']),
              child: Text('edit ${s.pathParameters['id']}'),
            ),
          ),
        ),
        GoRoute(path: '/library/shelf', builder: (_, _) => const Text('shelf')),
        GoRoute(
          path: '/store/checkout',
          builder: (_, _) => const Text('checkout'),
        ),
        GoRoute(path: '/other', builder: (_, _) => const Text('other')),
      ],
    ),
  );
  guard.bind(router);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return _App(router, session);
}

void main() {
  group('T-0066-AC2 a signed-out user lands on sign-in with from set', () {
    testWidgets('T-0066-AC2 a cold link to /me/lists/new, then signing in '
        'shows the editor with home below it', (tester) async {
      final app = await _app(
        tester,
        signedIn: false,
        initial: '/me/lists/new',
      );

      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fnew');
      expect(find.byKey(_signInPage), findsOneWidget);
      expect(app.router.canPop(), isTrue, reason: 'home is below sign-in');

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();

      expect(app.location, '/me/lists/new');
      expect(find.byKey(_finishButton), findsOneWidget);
      expect(find.byKey(_signInPage), findsNothing);
      expect(app.router.canPop(), isTrue, reason: 'a back stack to home');
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_home), findsOneWidget);
      expect(find.byKey(_signInPage), findsNothing, reason: 'it was replaced');
    });

    testWidgets('T-0066-AC2 a link while the app runs (a go) lands on '
        'sign-in, and sign-in leads to the target', (tester) async {
      final app = await _app(tester, signedIn: false);

      app.router.go('/me/lists/new');
      await tester.pumpAndSettle();
      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fnew');

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(app.location, '/me/lists/new');
      expect(find.byKey(_finishButton), findsOneWidget);
    });

    testWidgets('T-0066-AC2 a link in its running-app form '
        '(miniclient://app/...) is read as its path', (tester) async {
      final app = await _app(tester, signedIn: false);

      app.router.go('miniclient://app/me/lists/l-1/edit');
      await tester.pumpAndSettle();

      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fl-1%2Fedit');
    });

    testWidgets('T-0066-AC2 pushes onto /library/** and /store/checkout land '
        'on sign-in with from set, and Not now returns to where they came '
        'from', (tester) async {
      final app = await _app(tester, signedIn: false);

      unawaited(app.router.push('/library/shelf'));
      await tester.pumpAndSettle();
      expect(app.location, '/auth/sign-in?from=%2Flibrary%2Fshelf');
      await tester.tap(find.byKey(_notNowButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_home), findsOneWidget);
      expect(app.location, '/');

      unawaited(app.router.push('/store/checkout'));
      await tester.pumpAndSettle();
      expect(app.location, '/auth/sign-in?from=%2Fstore%2Fcheckout');
      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(find.text('checkout'), findsOneWidget);
      expect(app.location, '/store/checkout');
    });

    testWidgets('T-0066-AC2 Not now on a cold link ends at home', (
      tester,
    ) async {
      final app = await _app(
        tester,
        signedIn: false,
        initial: '/me/lists/new',
      );

      await tester.tap(find.byKey(_notNowButton));
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      // go_router keeps the query of the link it popped away from.
      expect(Uri.parse(app.location).path, '/');
      expect(app.session.isSignedIn, isFalse);
    });

    testWidgets('T-0066-AC2 Back from sign-in ends at home too, and nobody '
        'is signed in', (tester) async {
      final app = await _app(
        tester,
        signedIn: false,
        initial: '/me/lists/new',
      );

      app.router.pop();
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      expect(app.session.isSignedIn, isFalse);
    });
  });

  group('T-0066-AC2 a signed-in user is never redirected', () {
    for (final target in [
      '/me/lists/new',
      '/library/shelf',
      '/store/checkout',
    ]) {
      testWidgets('T-0066-AC2 signed in, a cold link to $target shows it', (
        tester,
      ) async {
        final app = await _app(tester, initial: target);

        expect(app.location, target);
        expect(find.byKey(_signInPage), findsNothing);
      });
    }

    testWidgets('T-0066-AC2 signed in, a push and a go to a protected '
        'location are not redirected', (tester) async {
      final app = await _app(tester);

      app.create();
      await tester.pumpAndSettle();
      expect(app.location, '/me/lists/new');
      expect(find.byKey(_signInPage), findsNothing);

      app.router.go('/store/checkout');
      await tester.pumpAndSettle();
      expect(app.location, '/store/checkout');
    });
  });

  group('T-0066-AC2 a foreign from falls back to home', () {
    for (final from in [
      'https://evil.com',
      '//evil.com',
      '/%2Fevil.com',
      '/\\evil.com',
      '/auth/sign-in',
    ]) {
      testWidgets('T-0066-AC2 after signing in from $from the app is at '
          'home', (tester) async {
        final app = await _app(
          tester,
          signedIn: false,
          initial: AppLocations.signIn(from: from),
        );
        expect(find.byKey(_signInPage), findsOneWidget);

        await tester.tap(find.byKey(_signInButton));
        await tester.pumpAndSettle();

        expect(find.byKey(_home), findsOneWidget);
        expect(app.location, '/');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('T-0066-AC2 the refresh follows the session', () {
    testWidgets('T-0066-AC2 signing out on /me/lists/l-1/edit redirects to '
        'sign-in with that location as from', (tester) async {
      final app = await _app(tester, initial: '/me/lists/l-1/edit');
      expect(find.byKey(_editor), findsOneWidget);

      app.session.signOut();
      await tester.pumpAndSettle();

      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fl-1%2Fedit');
      expect(find.byKey(_signInPage), findsOneWidget);
      expect(find.byKey(_editor), findsNothing);

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(app.location, '/me/lists/l-1/edit');
      expect(find.byKey(_editor), findsOneWidget);
    });

    testWidgets('T-0066-AC2 a protected page under an open one does not '
        'survive a sign-out: no protected page is reachable by Back', (
      tester,
    ) async {
      final app = await _app(tester);

      app.edit('l-1');
      await tester.pumpAndSettle();
      unawaited(app.router.push('/other'));
      await tester.pumpAndSettle();
      expect(find.text('other'), findsOneWidget);

      app.session.signOut();
      await tester.pumpAndSettle();

      // The topmost protected page is where the user goes back to.
      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fl-1%2Fedit');
      expect(find.byKey(_signInPage), findsOneWidget);
      expect(find.byKey(_editor), findsNothing);
      expect(find.text('other'), findsNothing);
      expect(app.got, ['e:l-1:null'], reason: 'the editor call ended once');

      // Back from sign-in is home: there is no protected page below.
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(_home), findsOneWidget);
      expect(app.router.canPop(), isFalse);
      expect(find.byKey(_editor), findsNothing);
    });

    testWidgets('T-0066-AC2 a signed-in user at /auth/sign-in goes on to '
        'its from, or home when it is foreign', (tester) async {
      final app = await _app(tester);

      app.router.go(AppLocations.signIn(from: '/store/checkout'));
      await tester.pumpAndSettle();
      expect(find.text('checkout'), findsOneWidget);
      expect(find.byKey(_signInPage), findsNothing);

      app.router.go(AppLocations.signIn(from: 'https://evil.com'));
      await tester.pumpAndSettle();
      expect(find.byKey(_home), findsOneWidget);
      expect(find.byKey(_signInPage), findsNothing);
    });

    testWidgets('T-0066-AC2 signing out on an open page changes nothing', (
      tester,
    ) async {
      final app = await _app(tester, initial: '/other');

      app.session.signOut();
      await tester.pumpAndSettle();

      expect(app.location, '/other');
      expect(find.text('other'), findsOneWidget);
    });

    testWidgets('T-0066-AC2 signing in while sign-in shows does not move the '
        'page: the user decides', (tester) async {
      final app = await _app(
        tester,
        signedIn: false,
        initial: '/me/lists/new',
      );

      app.session.signIn();
      await tester.pumpAndSettle();

      expect(find.byKey(_signInPage), findsOneWidget);
      expect(app.location, '/auth/sign-in?from=%2Fme%2Flists%2Fnew');
    });

    testWidgets('T-0066-AC2 a sign-in answered in the same turn as the '
        'session change still leaves the sign-in page (a sign-in does not '
        'refresh the router: its restore would bring the page back)', (
      tester,
    ) async {
      final app = await _app(tester, signedIn: false);
      final answers = <bool>[];
      unawaited(
        requestAppSignIn(
          routerRef: RouterRef()..attach(app.router),
          session: app.session,
          purpose: SignInPurpose.favourites,
        ).then(answers.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_signInNowButton));
      await tester.pumpAndSettle();

      expect(answers, [true]);
      expect(find.byKey(_signInPage), findsNothing);
      expect(find.byKey(_home), findsOneWidget);
    });

    testWidgets('T-0066-AC2 the session is listened to while the router '
        'lives, and not after it is disposed', (tester) async {
      final session = _FakeSession();
      final guard = SignInGuard(session);
      final router = GoRouter(
        refreshListenable: guard.refresh,
        redirect: (context, state) => guard.redirect(state.uri),
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(session.changes.hasListener, isTrue);

      router.dispose();
      await tester.pumpWidget(const SizedBox());

      expect(session.changes.hasListener, isFalse);
      await session.changes.close();
    });
  });

  group('T-0066-AC2 every AppFlows caller completes exactly once', () {
    testWidgets('T-0066-AC2 a push guarded, then signed in: the caller gets '
        'null once (its page was replaced by go(from)), and the editor '
        'a go built answers nobody', (tester) async {
      final app = await _app(tester, signedIn: false);

      app.create();
      await tester.pumpAndSettle();
      expect(find.byKey(_signInPage), findsOneWidget);
      expect(app.got, isEmpty);

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_finishButton), findsOneWidget);
      expect(app.got, ['c:null']);

      await tester.tap(find.byKey(_finishButton));
      await tester.pumpAndSettle();
      expect(app.got, ['c:null'], reason: 'finishing adds nothing');
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0066-AC2 a push guarded, then Not now: null once', (
      tester,
    ) async {
      final app = await _app(tester, signedIn: false);

      app.create();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_notNowButton));
      await tester.pumpAndSettle();

      expect(app.got, ['c:null']);
      expect(find.byKey(_home), findsOneWidget);
    });

    testWidgets('T-0066-AC2 a push guarded, then Back: null once', (
      tester,
    ) async {
      final app = await _app(tester, signedIn: false);

      app.create();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();

      expect(app.got, ['c:null']);
    });

    testWidgets('T-0066-AC2 an edit open, the session ends: the guard '
        'replaces the editor with sign-in and the caller gets null once '
        '(the page is kept by its key through the refresh)', (tester) async {
      final app = await _app(tester);

      app.edit('l-1');
      await tester.pumpAndSettle();
      expect(find.byKey(_editor), findsOneWidget);
      expect(app.got, isEmpty);

      app.session.signOut();
      await tester.pumpAndSettle();
      expect(find.byKey(_signInPage), findsOneWidget);
      expect(app.got, ['e:l-1:null'], reason: 'the editor page is gone');

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_editor), findsOneWidget);
      expect(app.got, ['e:l-1:null'], reason: 'still exactly one answer');
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0066-AC2 a session event that changes nothing for a '
        'signed-in user leaves the editor alone, and it answers its caller '
        'once', (tester) async {
      final app = await _app(tester);

      app.edit('l-1');
      await tester.pumpAndSettle();
      // A session event that changes nothing for a signed-in user.
      app.session.signIn();
      await tester.pumpAndSettle();
      expect(find.byKey(_editor), findsOneWidget);

      await tester.tap(find.byKey(_editor));
      await tester.pumpAndSettle();

      expect(app.got, ['e:l-1:l-1']);
      expect(find.byKey(_home), findsOneWidget);
    });

    testWidgets('T-0066-AC2 after every call ended, no router listener is '
        'left (no change reaches a watch)', (tester) async {
      var changes = 0;
      AppFlows.debugOnChange = () => changes++;
      addTearDown(() => AppFlows.debugOnChange = null);
      final app = await _app(tester, signedIn: false);

      app.create();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();
      expect(app.got, ['c:null']);

      changes = 0;
      app.router.go('/other');
      await tester.pumpAndSettle();
      app.session.signOut();
      await tester.pumpAndSettle();
      expect(changes, 0, reason: 'the ended call listens to nothing');
    });
  });

  group('T-0066-AC3 requestAppSignIn', () {
    Future<(_App, RouterRef)> app(
      WidgetTester tester, {
      bool signedIn = false,
    }) async {
      final a = await _app(tester, signedIn: signedIn);
      return (a, RouterRef()..attach(a.router));
    }

    testWidgets('T-0066-AC3 already signed in answers true at once, with no '
        'screen', (tester) async {
      final (a, ref) = await app(tester, signedIn: true);

      final answer = await requestAppSignIn(
        routerRef: ref,
        session: a.session,
        purpose: SignInPurpose.favourites,
      );

      expect(answer, isTrue);
      expect(find.byKey(_signInPage), findsNothing);
      expect(a.location, '/');
    });

    testWidgets('T-0066-AC3 signing in on the screen answers true, once a '
        'session exists', (tester) async {
      final (a, ref) = await app(tester);
      final answers = <bool>[];

      unawaited(
        requestAppSignIn(
          routerRef: ref,
          session: a.session,
          purpose: SignInPurpose.readingLists,
        ).then(answers.add),
      );
      await tester.pumpAndSettle();
      expect(a.location, '/auth/sign-in?reason=readingLists');
      expect(answers, isEmpty, reason: 'the caller waits');

      await tester.tap(find.byKey(_signInButton));
      await tester.pumpAndSettle();

      expect(answers, [true]);
      expect(a.session.isSignedIn, isTrue);
      expect(find.byKey(_home), findsOneWidget, reason: 'back where it was');
    });

    testWidgets('T-0066-AC3 Not now answers false and signs nobody in', (
      tester,
    ) async {
      final (a, ref) = await app(tester);
      final answers = <bool>[];

      unawaited(
        requestAppSignIn(
          routerRef: ref,
          session: a.session,
          purpose: SignInPurpose.cart,
        ).then(answers.add),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_notNowButton));
      await tester.pumpAndSettle();

      expect(answers, [false]);
      expect(a.session.isSignedIn, isFalse);
    });

    testWidgets('T-0066-AC3 Back answers false, once', (tester) async {
      final (a, ref) = await app(tester);
      final answers = <bool>[];

      unawaited(
        requestAppSignIn(
          routerRef: ref,
          session: a.session,
          purpose: SignInPurpose.triviaResults,
        ).then(answers.add),
      );
      await tester.pumpAndSettle();
      a.router.pop();
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });

    testWidgets('T-0066-AC3 a session that ended before the answer is no '
        'true', (tester) async {
      final (a, ref) = await app(tester);
      final answers = <bool>[];

      unawaited(
        requestAppSignIn(
          routerRef: ref,
          session: a.session,
          purpose: SignInPurpose.appearanceSync,
        ).then(answers.add),
      );
      await tester.pumpAndSettle();
      // Signing in answers `signedIn`, and the session ends in the same
      // turn (signed out elsewhere).
      await tester.tap(find.byKey(_signInButton));
      a.session.signOut();
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });

    test(
      'T-0066-AC3 before the router shows anything it answers false',
      () async {
        final ref = RouterRef();
        final router = ref.attach(
          GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
          ),
        );
        addTearDown(router.dispose);

        expect(
          await requestAppSignIn(
            routerRef: ref,
            session: _FakeSession(),
            purpose: SignInPurpose.favourites,
          ),
          isFalse,
        );
      },
    );

    test('T-0066-AC3 every purpose is a code the sign-in link carries', () {
      for (final purpose in SignInPurpose.values) {
        expect(
          Uri.parse(
            AppLocations.signIn(reason: purpose),
          ).queryParameters['reason'],
          purpose.name,
        );
      }
      expect(SignInPurpose.values.map((p) => p.name), [
        'favourites',
        'readingLists',
        'cart',
        'triviaResults',
        'appearanceSync',
      ]);
    });
  });

  test('T-0066-AC2 AppLocations.signIn builds the link with from and '
      'reason', () {
    expect(AppLocations.signIn(), '/auth/sign-in');
    expect(
      AppLocations.signIn(from: '/me/lists/new'),
      '/auth/sign-in?from=%2Fme%2Flists%2Fnew',
    );
    expect(
      AppLocations.signIn(reason: SignInPurpose.cart),
      '/auth/sign-in?reason=cart',
    );
    expect(
      AppLocations.signIn(from: '/store/checkout', reason: SignInPurpose.cart),
      '/auth/sign-in?from=%2Fstore%2Fcheckout&reason=cart',
    );
  });
}
