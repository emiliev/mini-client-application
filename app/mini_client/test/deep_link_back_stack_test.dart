// T-0049: every entity route nests under home (plan 01 §4.2), so a deep link
// opens `[home, target]`: the first screen has a back button, and Back leads
// home. Also P-092: a link that replaces an open editor frees home's buttons.
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
import 'package:mini_client/src/router/app_router.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');
const _details = ValueKey<String>('reading_list_editor.details');
const _signInForm = ValueKey<String>('auth_signin.form');

/// The links of AC1, each with a finder for its own screen.
final _links = <String, Finder>{
  AppLocations.characters: find.byKey(
    const ValueKey<String>('characters_list.grid'),
  ),
  AppLocations.character(100366): find.byKey(
    const ValueKey<String>('characters_details.name'),
  ),
  AppLocations.comic(501500): find.byKey(
    const ValueKey<String>('comics_details.title'),
  ),
  AppLocations.search('spi'): find.byType(TextField),
  AppLocations.newReadingList: find.byKey(_details),
};

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
    storage = Directory.systemTemp.createTempSync('deep_link_back_stack_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester, {String? coldStartLink}) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    if (coldStartLink != null) {
      links.offer(coldStartLink);
    }
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

  /// Taps Back exactly once on the screen that shows.
  Future<void> backOnce(WidgetTester tester) async {
    expect(find.byType(BackButton), findsWidgets, reason: 'a back button');
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
  }

  /// The exact walk home (plan 01 §4.2): one Back for every link, except
  /// a character's details, which sit under the characters list.
  Future<void> walkHome(WidgetTester tester, String link) async {
    if (link == AppLocations.character(100366)) {
      await backOnce(tester);
      expect(
        find.byKey(const ValueKey<String>('characters_list.grid')),
        findsOneWidget,
        reason: 'details sit under the characters list',
      );
      expect(find.byKey(_home), findsNothing);
    }
    await backOnce(tester);
    expect(find.byKey(_home), findsOneWidget, reason: 'one Back from $link');
    expect(find.byType(BackButton), findsNothing, reason: 'nothing below home');
  }

  for (final entry in _links.entries) {
    testWidgets('T-0049-AC1 a cold start from ${entry.key} shows a back '
        'button that leads home', (tester) async {
      await boot(tester, coldStartLink: 'miniclient://app${entry.key}');
      if (entry.key == AppLocations.newReadingList) {
        await signInOnTheForm(tester);
      }

      expect(entry.value, findsWidgets, reason: 'the linked screen');
      expect(find.byKey(_home), findsNothing, reason: 'covered by the link');
      expect(find.byType(BackButton), findsWidgets, reason: 'a back button');

      await walkHome(tester, entry.key);
    });

    testWidgets(
      'T-0049-AC2 ${entry.key == AppLocations.character(100366) ? 'T-0054-AC4 ' : ''}a link to the running app (${entry.key}) '
      'stacks [home, target]; Back returns to home',
      (tester) async {
        await boot(tester);
        // Something else is open first: Back must not lead there. Not for the
        // character's details: they sit under the characters list, so a list
        // that was already open would give the same stack from a push as from
        // a go (T-0054-AC4, P-098). From home, only a go builds the list below.
        if (entry.key != AppLocations.character(100366)) {
          await tester.tap(find.text('Characters'));
          await tester.pumpAndSettle();
        }

        await _pushLink(tester, 'miniclient://app${entry.key}');
        await tester.pumpAndSettle();
        if (entry.key == AppLocations.newReadingList) {
          await signInOnTheForm(tester);
        }
        expect(entry.value, findsWidgets, reason: 'the linked screen');

        await walkHome(tester, entry.key);
      },
    );
  }

  test('T-0049-AC3 the app router treats a FlowCall extra as transient', () {
    final router = buildAppRouter(
      initialLocation: AppLocations.home,
      session: _SignedOut(),
    );
    addTearDown(router.dispose);

    expect(router.configuration.extraCodec, isA<FlowExtraCodec>());
  });

  testWidgets('T-0049-AC3 a link to home replaces an open editor: its '
      'buttons work again', (tester) async {
    await boot(tester);
    await tester.ensureVisible(find.byKey(newReadingListKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(newReadingListKey));
    await tester.pumpAndSettle();
    await signInOnTheForm(tester);
    expect(find.byKey(_details), findsOneWidget);

    await _pushLink(tester, 'miniclient://app/');
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);
    expect(find.byKey(_details), findsNothing);

    await tester.ensureVisible(find.byKey(newReadingListKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(newReadingListKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(_details),
      findsOneWidget,
      reason: 'the second tap opened the editor (the first caller got null)',
    );
  });
}

/// A signed-out session for a router that is built without a root container.
class _SignedOut implements SessionReader {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isSignedIn => false;

  @override
  AuthStatus get status => AuthStatus.signedOut;

  @override
  Stream<AuthStatus> get authState => const Stream<AuthStatus>.empty();
}
