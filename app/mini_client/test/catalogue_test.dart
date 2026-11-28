// T-0074 (P2-08 AC1): every generated flow is reachable from the catalogue
// route. The test reads `catalogueEntries`, which `mcgen wire` writes, so a
// tree with a new generated flow (the T-0074-AC3 probe) checks that flow
// with no change here.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _home = Key('home.placeholder');

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('catalogue_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  /// The real app (every wiring, the app's mock domains), opened on [link].
  Future<GoRouter> boot(WidgetTester tester, String link) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    links.offer(link);
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
    return GoRouter.of(tester.element(find.byType(Navigator).first));
  }

  mcTestWidgets('T-0074-AC3 a link opens the catalogue with home under it, '
      'listing every generated flow', (tester) async {
    final router = await boot(tester, AppLocations.catalogue);

    expect(router.state.uri.toString(), AppLocations.catalogue);
    expect(find.text('Catalogue'), findsOneWidget);
    if (catalogueEntries.isEmpty) {
      expect(find.byKey(catalogueEmptyKey), findsOneWidget);
    }
    for (final e in catalogueEntries) {
      expect(find.byKey(catalogueEntryKey(e.module)), findsOneWidget);
    }
    expect(router.canPop(), isTrue, reason: 'nested under home (T-0049)');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);
    expect(
      find.text('Catalogue'),
      findsNothing,
      reason: 'home has no catalogue entry point',
    );
  });

  for (final e in catalogueEntries) {
    mcTestWidgets('T-0074-AC3 the catalogue opens ${e.module} at its route, '
        'and Back returns to the catalogue', (tester) async {
      final router = await boot(tester, AppLocations.catalogue);

      await tester.tap(find.byKey(catalogueEntryKey(e.module)));
      await tester.pumpAndSettle();

      if (SignInGuard.isProtectedLocation(Uri.parse(e.location))) {
        // Signed out, a protected flow asks for sign-in first (F-0066).
        expect(router.state.uri.path, '/auth/sign-in');
      } else {
        expect(router.state.uri.toString(), e.location);
        expect(router.state.name, e.module, reason: 'its own typed route');
      }
      expect(find.byKey(catalogueEntryKey(e.module)), findsNothing);
      expect(tester.takeException(), isNull);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(catalogueEntryKey(e.module)), findsOneWidget);
    });
  }

  mcTestWidgets('T-0074-AC3 a catalogue tile pushes its location, and Back '
      'returns to the catalogue', (tester) async {
    const entry = CatalogueEntry(module: 'some_flow', location: '/some-flow');
    final router = GoRouter(
      initialLocation: '/catalogue',
      routes: [
        GoRoute(
          path: '/catalogue',
          builder: (context, state) => const CataloguePage(entries: [entry]),
        ),
        GoRoute(
          path: '/some-flow',
          name: 'some_flow',
          builder: (context, state) => const Text('some flow'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('/some-flow'), findsOneWidget);
    await tester.tap(find.byKey(catalogueEntryKey('some_flow')));
    await tester.pumpAndSettle();
    expect(find.text('some flow'), findsOneWidget);
    expect(router.state.name, 'some_flow');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(catalogueEntryKey('some_flow')), findsOneWidget);
  });
}
