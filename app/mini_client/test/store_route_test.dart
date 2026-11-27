// T-0056: store_home inside the real app (the full root list, every wiring
// and the app's mock domains): the Store entry on home, the store's ways out
// to a comic and a search, and the deep links with their back stacks.
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
const _storeBody = ValueKey<String>('store_home.body');
const _categoryGrid = ValueKey<String>('store_category.grid');
const _categoryTitle = ValueKey<String>('store_category.title');
const _comicTitle = ValueKey<String>('comics_details.title');

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('store_route_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester, {String? coldStartLink}) async {
    // The iPhone 17 Pro surface (mcReferenceSurface), not the 800x600 default.
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

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  Future<void> openStoreFromHome(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Store'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
  }

  Future<void> tapInStore(WidgetTester tester, String text) async {
    final target = find.descendant(
      of: find.byKey(_storeBody),
      matching: find.text(text),
    );
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(_storeBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target.hitTestable().first);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  testWidgets("T-0056-AC5 home's Store entry opens the store, whose sections "
      'load from the app mock domains', (tester) async {
    await boot(tester);
    expect(find.byKey(_home), findsOneWidget);

    await openStoreFromHome(tester);

    expect(router(tester).state.uri.toString(), AppLocations.store);
    for (final text in ['Highlights', 'Deals', 'New this week']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    // The deals count down against the mocked backend's clock.
    expect(find.text('Ends in 1 day'), findsOneWidget);
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0056-AC3 a deal opens its comic page, and Back returns to '
      'the store', (tester) async {
    await boot(tester);
    await openStoreFromHome(tester);

    await tapInStore(tester, 'Amber Frontier #2');

    expect(router(tester).state.uri.toString(), AppLocations.comic(501501));
    expect(
      tester.widget<Text>(find.byKey(_comicTitle)).data,
      'Amber Frontier #2',
    );
    await back(tester);
    expect(find.byKey(_storeBody), findsOneWidget);
  });

  testWidgets('T-0056-AC3 a search banner opens the search with its query', (
    tester,
  ) async {
    await boot(tester);
    await openStoreFromHome(tester);

    final carousel = find
        .descendant(
          of: find.byKey(const ValueKey('store_home.banners.content')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Amber season'),
      150,
      scrollable: carousel,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amber season'));
    await tester.pumpAndSettle();

    expect(router(tester).state.uri.toString(), AppLocations.search('amber'));
  });

  testWidgets('T-0056-AC5 the cold link miniclient://app/store opens the '
      'store over home, and Back goes home', (tester) async {
    await boot(tester, coldStartLink: 'miniclient://app/store');

    expect(find.byKey(_storeBody), findsOneWidget);
    expect(find.byKey(_home), findsNothing);
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0056-AC5 the cold link to a category opens it over the store '
      'over home, and Back walks that path', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app/store/categories/heroes',
    );

    expect(find.byKey(_categoryGrid), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(_categoryTitle)).data, 'Heroes');
    expect(find.text('Ember Chronicles #1'), findsOneWidget);

    await back(tester);
    expect(find.byKey(_storeBody), findsOneWidget);
    expect(router(tester).state.uri.toString(), AppLocations.store);
    await back(tester);
    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('T-0056-AC3 a category opens inside the store flow: the route '
      'stays /store, and Back returns to the store', (tester) async {
    await boot(tester);
    await openStoreFromHome(tester);

    await tapInStore(tester, 'Cosmic');

    expect(tester.widget<Text>(find.byKey(_categoryTitle)).data, 'Cosmic');
    expect(router(tester).state.uri.toString(), AppLocations.store);
    await back(tester);
    expect(find.byKey(_storeBody), findsOneWidget);
    expect(find.byKey(_categoryGrid), findsNothing);
  });
}
