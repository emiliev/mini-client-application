// T-0054-AC4 (P-097): the not-found screen is reachable at any path, cold or
// running, opens as [home, not-found], and always has a way home.
import 'dart:async';
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';
import 'package:mini_client/src/pages/placeholder_pages.dart';
import 'package:mini_client/src/router/app_router.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');
const _notFound = Key('not.found');

/// The paths that find nothing: an unknown path, a deeper one, a bad id.
const _missing = ['/nope', '/a/b/c', '/comics/abc'];

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
    storage = Directory.systemTemp.createTempSync('not_found_test');
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

  /// How many pages the router holds (the stack, not the screens).
  int depth(WidgetTester tester, Key on) {
    final router = GoRouter.of(tester.element(find.byKey(on)));
    return router.routerDelegate.currentConfiguration.matches.length;
  }

  void expectHomeAlone(String reason) {
    expect(find.byKey(_home), findsOneWidget, reason: reason);
    expect(find.byKey(_notFound), findsNothing, reason: reason);
    expect(find.byType(BackButton), findsNothing, reason: 'nothing below home');
  }

  for (final path in _missing) {
    testWidgets('T-0054-AC4 a cold start at $path shows not-found with a back '
        'button and Go home, over home', (tester) async {
      await boot(tester, coldStartLink: 'miniclient://app$path');

      expect(find.byKey(_notFound), findsOneWidget);
      expect(find.text('Nothing lives at $path'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(notFoundHomeKey), findsOneWidget);
      expect(find.text('Go home'), findsOneWidget);
      expect(depth(tester, _notFound), 2, reason: '[home, not-found]');
    });

    testWidgets('T-0054-AC4 a cold start at $path: Back reaches home in one '
        'action', (tester) async {
      await boot(tester, coldStartLink: 'miniclient://app$path');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expectHomeAlone('one Back');
    });

    testWidgets('T-0054-AC4 a cold start at $path: Go home reaches home in '
        'one action', (tester) async {
      await boot(tester, coldStartLink: 'miniclient://app$path');

      await tester.tap(find.byKey(notFoundHomeKey));
      await tester.pumpAndSettle();

      expectHomeAlone('one Go home');
    });

    testWidgets('T-0054-AC4 a link to $path in the running app stacks '
        '[home, not-found]', (tester) async {
      await boot(tester);
      // Something else is open first: it is gone after the link (go).
      await tester.tap(find.text('Characters'));
      await tester.pumpAndSettle();

      await _pushLink(tester, 'miniclient://app$path');
      await tester.pumpAndSettle();

      expect(find.byKey(_notFound), findsOneWidget);
      expect(find.text('Nothing lives at $path'), findsOneWidget);
      expect(depth(tester, _notFound), 2, reason: '[home, not-found]');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expectHomeAlone('Back leads home, not to the characters list');
    });

    testWidgets('T-0054-AC4 a link to $path in the running app: Go home', (
      tester,
    ) async {
      await boot(tester);

      await _pushLink(tester, 'miniclient://app$path');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(notFoundHomeKey));
      await tester.pumpAndSettle();

      expectHomeAlone('Go home');
    });
  }

  testWidgets('T-0054-AC4 not-found shows the query a link carried, and a '
      'second missing link replaces the first', (tester) async {
    await boot(tester, coldStartLink: 'miniclient://app/nope?x=1');
    expect(find.text('Nothing lives at /nope?x=1'), findsOneWidget);

    await _pushLink(tester, 'miniclient://app/other');
    await tester.pumpAndSettle();

    expect(find.text('Nothing lives at /other'), findsOneWidget);
    expect(depth(tester, _notFound), 2);
  });

  testWidgets('T-0054-AC4 a not-found that was pushed over a page pops '
      'instead of going home', (tester) async {
    await boot(tester);
    final router = GoRouter.of(tester.element(find.byKey(_home)));
    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();

    unawaited(router.push<void>(notFoundLocation('/pushed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(_notFound), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('characters_list.grid')),
      findsOneWidget,
      reason: 'Back pops what is under it',
    );
  });

  for (final byButton in [false, true]) {
    testWidgets('T-0054-AC4 a not-found with nothing under it goes home on '
        '${byButton ? 'Go home' : 'Back'}', (tester) async {
      final router = GoRouter(
        initialLocation: '/lonely',
        routes: [
          GoRoute(path: '/', builder: (c, s) => const Text('home')),
          GoRoute(
            path: '/lonely',
            builder: (c, s) => const NotFoundPage(location: '/lonely'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: McTheme.light,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);

      await tester.tap(
        byButton ? find.byKey(notFoundHomeKey) : find.byType(BackButton),
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.byKey(_notFound), findsNothing);
    });
  }

  test('T-0054-AC4 the URLs of the app are unchanged', () {
    expect(AppLocations.home, '/');
    expect(AppLocations.characters, '/characters');
    expect(AppLocations.character(1), '/characters/1');
    expect(AppLocations.comic(2), '/comics/2');
    expect(AppLocations.search('spi'), '/search?q=spi');
    expect(AppLocations.newReadingList, '/me/lists/new');
    expect(AppLocations.editReadingList('l-1'), '/me/lists/l-1/edit');
  });
}
