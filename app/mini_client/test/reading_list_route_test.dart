// T-0048: the reading-list editor inside the real app (the full root list,
// every wiring and the app's mock domains): home awaits the editor's result
// through the router (plan 01 §4.3), and the deep link opens the editor.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

const _details = ValueKey<String>('reading_list_editor.details');
const _signInForm = ValueKey<String>('auth_signin.form');

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
    storage = Directory.systemTemp.createTempSync('reading_list_route_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester) async {
    // The iPhone 17 Pro surface (mcReferenceSurface), not the 800x600 default.
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

  /// Signs in on the sign-in form with the first demo account: the session's
  /// real file write needs real time (F-0038).
  Future<void> signInOnTheForm(WidgetTester tester, {String? reason}) async {
    expect(find.byKey(_signInForm), findsOneWidget);
    if (reason != null) {
      expect(find.text(reason), findsOneWidget);
    }
    await tester.tap(
      find.byKey(
        const ValueKey<String>('auth_signin.demo.reader@mini-client.test'),
      ),
    );
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

  /// Home's own Sign in entry (T-0066), then the form.
  Future<void> signInFromHome(WidgetTester tester) async {
    expect(find.text('Signed out'), findsOneWidget);
    await tap(tester, find.byKey(signInKey));
    await signInOnTheForm(tester);
    expect(find.text('Signed in as u-100'), findsOneWidget);
  }

  testWidgets('T-0048-AC6 home awaits the editor and shows the list id the '
      'wiring returned', (tester) async {
    await boot(tester);
    await signInFromHome(tester);

    await tap(tester, find.byKey(newReadingListKey));
    expect(find.text('New reading list'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Amber reads');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Next'));
    await tap(tester, find.byKey(_result(500060)));
    await tap(tester, find.byKey(_result(500061)));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Create list'));

    expect(find.byKey(const Key('home.placeholder')), findsOneWidget);
    expect(find.text('List created: l-5'), findsOneWidget);
  });

  testWidgets('T-0048-AC3 home opens the created list in the editor, which '
      'returns the same id once saved', (tester) async {
    await boot(tester);
    await signInFromHome(tester);
    await tap(tester, find.byKey(newReadingListKey));
    await tester.enterText(find.byType(TextField).first, 'Amber reads');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Next'));
    await tap(tester, find.byKey(_result(500060)));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Create list'));

    await tap(tester, find.byKey(editReadingListKey));
    expect(find.text('Edit reading list'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Amber reads',
    );
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Next'));
    await tap(tester, find.text('Save changes'));

    expect(find.text('List saved: l-5'), findsOneWidget);
  });

  testWidgets('T-0048-AC6 leaving the editor by Back gives home nothing', (
    tester,
  ) async {
    await boot(tester);
    await signInFromHome(tester);
    await tap(tester, find.byKey(newReadingListKey));

    await tap(tester, find.byType(BackButton));

    expect(find.byKey(const Key('home.placeholder')), findsOneWidget);
    expect(find.byKey(readingListResultKey), findsNothing);
  });

  testWidgets('T-0048-AC5 the link miniclient://app/me/lists/new opens the '
      'editor (after the sign-in it asks for)', (tester) async {
    await boot(tester);

    await _pushLink(tester, 'miniclient://app/me/lists/new');
    await tester.pumpAndSettle();
    await signInOnTheForm(tester);

    expect(find.byKey(_details), findsOneWidget);
    expect(find.text('New reading list'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('T-0048-AC5 a double tap on New reading list opens one editor', (
    tester,
  ) async {
    await boot(tester);
    await tester.ensureVisible(find.byKey(newReadingListKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(newReadingListKey));
    await tester.tap(find.byKey(newReadingListKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    await signInOnTheForm(tester);
    expect(find.byKey(_signInForm), findsNothing, reason: 'one sign-in');

    await tap(tester, find.byType(BackButton));
    expect(
      find.byKey(const Key('home.placeholder')),
      findsOneWidget,
      reason: 'one Back leads home: there was one editor',
    );
    expect(find.byKey(_details), findsNothing);
  });
}
