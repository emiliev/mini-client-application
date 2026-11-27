// T-0066: the sign-in guard and the sign-in screen inside the real app (the
// full root list, every wiring, the real router and the real form): AC2, the
// guard, and AC3, the callers.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';
import 'package:mini_client/src/pages/placeholder_pages.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');
const _details = ValueKey<String>('reading_list_editor.details');
const _signInForm = ValueKey<String>('auth_signin.form');
const _notNow = ValueKey<String>('auth_signin.not_now');
const _reader = ValueKey<String>('auth_signin.demo.reader@mini-client.test');

/// The search result of comic [id] in the editor's step 2.
ValueKey<String> _result(int id) =>
    ValueKey<String>('reading_list_editor.result.$id');

/// What iOS sends for a link once the app runs.
Future<void> _pushLink(WidgetTester tester, String location) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('sign_in_guard_app_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: McFixtureAssetBundle(),
        child: MiniClientApp(
          links: links,
          initializers: (routerRef) => rootInitializers(
            config: () async => _config,
            storageDirectory: storage,
            monitoringSinks: [InMemorySink()],
            mockDomains: appMockDomains,
            routerRef: routerRef,
            wirings: wiringInitializers,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  GoRouter router(WidgetTester tester) => diContainer<GoRouter>();

  String location(WidgetTester tester) {
    final config = router(tester).routerDelegate.currentConfiguration;
    final last = config.last;
    return (last is ImperativeRouteMatch ? last.matches.uri : config.uri)
        .toString();
  }

  /// Signs in on the form with the first demo account (the session's real
  /// file write needs real time, F-0038).
  Future<void> signInOnTheForm(WidgetTester tester) async {
    expect(find.byKey(_signInForm), findsOneWidget);
    await tester.tap(find.byKey(_reader));
    await tester.pump();
    await tester.tap(find.byKey(McFormScaffold.submitKey));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      // Not `pumpAndSettle`: the form's spinner runs until the answer.
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(_signInForm).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
    expect(find.byKey(_signInForm), findsNothing);
    expect(diContainer<SessionReader>().isSignedIn, isTrue);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder.hitTestable());
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> createList(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Amber reads');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Next'));
    await tap(tester, find.byKey(_result(500060)));
    await tap(tester, find.byKey(_result(500061)));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Create list'));
  }

  testWidgets("T-0066-AC2 home's New reading list while signed out goes to "
      'sign-in with from, then to the editor with home below it', (
    tester,
  ) async {
    await boot(tester);

    await tap(tester, find.byKey(newReadingListKey));

    expect(
      location(tester),
      AppLocations.signIn(from: AppLocations.newReadingList),
    );
    expect(find.byKey(_signInForm), findsOneWidget);
    await signInOnTheForm(tester);

    expect(find.byKey(_details), findsOneWidget, reason: 'the editor');
    expect(router(tester).canPop(), isTrue, reason: 'home is below it');
    await tap(tester, find.byType(BackButton));
    expect(find.byKey(_home), findsOneWidget);
    expect(find.byKey(_signInForm), findsNothing);
    expect(find.byKey(readingListResultKey), findsNothing);
  });

  testWidgets('T-0066-AC2 the editor result after a guard (F-0049 note 11): '
      'home never gets the list id, learns of the change through the '
      "editor's DataChanged announcement, and says so", (tester) async {
    await boot(tester);

    await tap(tester, find.byKey(newReadingListKey));
    await signInOnTheForm(tester);
    await createList(tester);

    expect(find.byKey(_home), findsOneWidget);
    expect(find.byKey(readingListsChangedKey), findsOneWidget);
    expect(find.text('Reading lists changed'), findsOneWidget);
    expect(find.byKey(readingListResultKey), findsNothing);
    expect(find.text('List created: l-5'), findsNothing);
  });

  testWidgets('T-0066-AC2 Not now on the guarded sign-in ends at home, '
      'signed out, with nothing changed', (tester) async {
    await boot(tester);

    await tap(tester, find.byKey(newReadingListKey));
    await tap(tester, find.byKey(_notNow));

    expect(find.byKey(_home), findsOneWidget);
    expect(find.byKey(_signInForm), findsNothing);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
    expect(find.byKey(readingListsChangedKey), findsNothing);
    // The next tap is not swallowed by a stale wait.
    await tap(tester, find.byKey(newReadingListKey));
    expect(find.byKey(_signInForm), findsOneWidget);
  });

  testWidgets('T-0066-AC2 signed in, a link to /me/lists/new opens the '
      'editor with no sign-in', (tester) async {
    await boot(tester);
    await tap(tester, find.byKey(signInKey));
    await signInOnTheForm(tester);

    await _pushLink(tester, 'miniclient://app/me/lists/new');
    await tester.pumpAndSettle();

    expect(find.byKey(_details), findsOneWidget);
    expect(find.byKey(_signInForm), findsNothing);
  });

  testWidgets('T-0066-AC2 a running link to /me/lists/new while signed out '
      'goes to sign-in, then to the editor', (tester) async {
    await boot(tester);

    await _pushLink(tester, 'miniclient://app/me/lists/new');
    await tester.pumpAndSettle();
    expect(
      location(tester),
      AppLocations.signIn(from: AppLocations.newReadingList),
    );
    await signInOnTheForm(tester);

    expect(find.byKey(_details), findsOneWidget);
    expect(router(tester).canPop(), isTrue);
  });

  testWidgets('T-0066-AC2 /store/checkout and /library/** are guarded too: '
      'a signed-out link goes to sign-in with from', (tester) async {
    await boot(tester);

    for (final target in ['/store/checkout', '/library/shelf']) {
      await _pushLink(tester, 'miniclient://app$target');
      await tester.pumpAndSettle();

      expect(
        location(tester),
        AppLocations.signIn(from: target),
        reason: target,
      );
      expect(find.byKey(_signInForm), findsOneWidget, reason: target);
      await tap(tester, find.byKey(_notNow));
      expect(find.byKey(_home), findsOneWidget, reason: target);
    }
  });

  testWidgets('T-0066-AC2 signing out on the editor redirects to sign-in, '
      'and signing in again returns to the editor', (tester) async {
    await boot(tester);
    await tap(tester, find.byKey(signInKey));
    await signInOnTheForm(tester);
    await tap(tester, find.byKey(newReadingListKey));
    expect(find.byKey(_details), findsOneWidget);

    // The user signs out somewhere else in the app (the editor is a pushed
    // page: the router's refresh alone would leave it on screen).
    await tester.runAsync(() => diContainer<AuthApi>().signOut());
    await tester.pumpAndSettle();

    expect(find.byKey(_signInForm), findsOneWidget);
    expect(find.byKey(_details), findsNothing);
    expect(
      location(tester),
      AppLocations.signIn(from: AppLocations.newReadingList),
    );

    await signInOnTheForm(tester);
    expect(find.byKey(_details), findsOneWidget);
    await tap(tester, find.byType(BackButton));
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0066-AC2 a foreign from falls back to home after the '
      'sign-in', (tester) async {
    await boot(tester);

    await _pushLink(
      tester,
      'miniclient://app${AppLocations.signIn(from: 'https://evil.com/me')}',
    );
    await tester.pumpAndSettle();
    await signInOnTheForm(tester);

    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets("T-0066-AC4 home's Sign in and Sign out entries", (
    tester,
  ) async {
    await boot(tester);
    expect(find.text('Signed out'), findsOneWidget);
    expect(find.byKey(signOutKey), findsNothing);

    await tap(tester, find.byKey(signInKey));
    expect(find.text('Use your Mini Client account.'), findsOneWidget);
    await signInOnTheForm(tester);
    expect(find.byKey(_home), findsOneWidget);
    expect(find.text('Signed in as u-100'), findsOneWidget);
    expect(find.byKey(signInKey), findsNothing);

    await tap(tester, find.byKey(signOutKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed out'), findsOneWidget);
    expect(diContainer<SessionReader>().isSignedIn, isFalse);
  });
}
