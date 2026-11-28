// T-0053-AC4 in the full app (the real router, the 7 wirings and the app's own
// root list): the screens a user walks through are tracked once each, with the
// page names the typed routes declare.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1",'
    '"analytics":{"defaultConsent":"granted"}}';

const _home = Key('home.placeholder');
const _storeBody = ValueKey<String>('store_home.body');
const _categoryGrid = ValueKey<String>('store_category.grid');

/// Every named route of the app, in the order the typed routes declare them.
const _expectedRouteNames = {
  'home',
  'placeholder_detail',
  'characters_list',
  'character_details',
  // T-0071: the character search.
  'characters_search',
  'comics_details',
  'creator_details',
  'discovery_search',
  'reading_list_new',
  'reading_list_edit',
  // T-0054: the not-found screen, nested under home.
  'not_found',
  'store_home',
  'store_category',
  'store_cart',
  // T-0064: the quiz's setup and a linked round.
  'trivia_setup',
  'trivia_play',
  // T-0070: the settings index, and (T-0063) the appearance settings under it.
  'settings_home',
  'settings_appearance',
  // T-0066: the sign-in form.
  'auth_sign_in',
};

Iterable<GoRoute> _routes(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
    }
    yield* _routes(route.routes);
  }
}

void main() {
  late Directory storage;
  late InMemoryAnalyticsSink sink;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('analytics_screens_test');
    sink = InMemoryAnalyticsSink();
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(
    WidgetTester tester, {
    String? coldStartLink,
    String config = _config,
  }) async {
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
            config: () async => config,
            storageDirectory: storage,
            monitoringSinks: [InMemorySink()],
            analyticsSinks: [sink],
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

  testWidgets('T-0053-AC4 home to the characters list and back records '
      'home, characters_list, home', (tester) async {
    await boot(tester);
    expect(find.byKey(_home), findsOneWidget);

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('characters_list.grid')),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);

    expect(sink.screens, ['home', 'characters_list', 'home']);
  });

  Future<void> openStore(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Store'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    expect(find.byKey(_storeBody), findsOneWidget);
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

  testWidgets('T-0056-AC7 home, store, a category, back, back records home, '
      'store_home, store_category, store_home, home: the category page is '
      'tracked from inside the flow', (tester) async {
    await boot(tester);
    await openStore(tester);
    await tapInStore(tester, 'Heroes');
    expect(find.byKey(_categoryGrid), findsOneWidget);

    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_storeBody), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);

    expect(sink.screens, [
      'home',
      'store_home',
      'store_category',
      'store_home',
      'home',
    ]);
  });

  testWidgets('T-0056-AC7 back from a comic opened on the category page '
      'tracks the category again, not the store route', (tester) async {
    await boot(tester);
    await openStore(tester);
    await tapInStore(tester, 'Heroes');
    await tester.tap(find.text('Ember Chronicles #1'));
    await tester.pumpAndSettle();
    expect(find.byKey(_categoryGrid), findsNothing);

    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_categoryGrid), findsOneWidget);

    expect(sink.screens, [
      'home',
      'store_home',
      'store_category',
      'comics_details',
      'store_category',
    ]);
  });

  testWidgets('T-0056-AC7 a cold link to a category: the store below it '
      'loads and tracks nothing; after Back each section loads and is viewed '
      'once, and a comic opened and closed over it changes nothing (one '
      'visit, review round)', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app${AppLocations.storeCategory('heroes')}',
    );
    expect(find.byKey(_categoryGrid), findsOneWidget);
    const store = [
      '/v1/store/banners',
      '/v1/store/deals',
      '/v1/store/categories',
      '/v1/store/featured',
    ];
    List<int> requests() => [
      for (final path in store)
        diContainer<MockBackend>().recentTraffic
            .where((t) => t.method == 'GET' && t.path == path)
            .length,
    ];
    List<String> viewed() => [
      for (final e in sink.events)
        if (e.name == 'store_section_viewed') e.params['section']! as String,
    ]..sort();
    // The one categories request is the category page's own name lookup.
    expect(requests(), [0, 0, 1, 0], reason: 'the store page is hidden');
    expect(viewed(), isEmpty);

    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_storeBody), findsOneWidget);
    expect(requests(), [1, 1, 2, 1]);
    expect(viewed(), ['banners', 'categories', 'deals', 'featured']);

    await tapInStore(tester, 'Amber Frontier #2');
    expect(find.byKey(_storeBody), findsNothing);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_storeBody), findsOneWidget);
    expect(requests(), [1, 1, 2, 1], reason: 'the same visit');
    expect(viewed(), hasLength(4));
  });

  testWidgets('T-0056-AC7 a cold link to a category tracks store_category '
      'once, and Back walks store_home then home', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app${AppLocations.storeCategory('heroes')}',
    );
    expect(find.byKey(_categoryGrid), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);

    expect(sink.screens, ['store_category', 'store_home', 'home']);
  });

  testWidgets('T-0053-AC4 a cold-start link tracks the linked screen, once', (
    tester,
  ) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app${AppLocations.character(100366)}',
    );

    expect(sink.screens, ['character_details']);
  });

  testWidgets('T-0067-AC1 a cold link to a character: Back walks the list '
      'and home, each tracked once', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app${AppLocations.character(100366)}',
    );
    expect(sink.screens, ['character_details']);

    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('characters_list.grid')),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);

    expect(sink.screens, ['character_details', 'characters_list', 'home']);
  });

  testWidgets('T-0067-AC3 in the app, a favourite saved from a profile '
      'tracks character_favourited with its id', (tester) async {
    await boot(
      tester,
      coldStartLink: 'miniclient://app${AppLocations.character(100366)}',
    );
    expect(
      [
        for (final e in sink.events)
          if (e.name == 'character_favourited') e,
      ],
      isEmpty,
    );

    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    const form = ValueKey<String>('auth_signin.form');
    expect(find.byKey(form), findsOneWidget);
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
      if (find.text('Remove from favourites').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Remove from favourites'), findsOneWidget);
    final tracked = [
      for (final e in sink.events)
        if (e.name == 'character_favourited') e.params,
    ];
    expect(tracked, [
      {'id': 100366},
    ]);
  });

  testWidgets('T-0053-AC4 every route of the app is named for analytics, '
      'with a valid unique screen name', (tester) async {
    await boot(tester);

    final router = GoRouter.of(tester.element(find.byKey(_home)));
    final names = [
      for (final r in _routes(router.configuration.routes)) r.name,
    ];

    expect(names, everyElement(isNotNull));
    expect(names.whereType<String>().toSet(), _expectedRouteNames);
    expect(names, hasLength(_expectedRouteNames.length), reason: 'unique');
    for (final name in names.whereType<String>()) {
      expect(AnalyticsRules.isValidName(name), isTrue, reason: name);
    }
  });

  testWidgets('T-0053-AC1 with consent unknown (a release-like config) '
      'nothing reaches the sink while the app runs', (tester) async {
    await boot(
      tester,
      config:
          '{"env":"perf","backend":{"seed":42,"latencyMs":0,'
          '"scenario":"happy"},"apiBaseUrl":"https://mock.mini-client.invalid/",'
          '"build":"1"}',
    );

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();

    expect(diContainer<Analytics>().consent, AnalyticsConsent.unknown);
    expect(sink.records, isEmpty);
    // home, the session start, characters_list: waiting for a choice.
    expect(diContainer<Analytics>().bufferedCount, 3);
  });

  testWidgets('T-0053-AC1 granting consent in the running app flushes the '
      'screens seen so far, in order', (tester) async {
    await boot(
      tester,
      config:
          '{"env":"perf","backend":{"seed":42,"latencyMs":0,'
          '"scenario":"happy"},"apiBaseUrl":"https://mock.mini-client.invalid/",'
          '"build":"1"}',
    );
    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();

    // The save is real file I/O: await it in real time, before teardown
    // deletes the directory (F-0050 section 7).
    await tester.runAsync(
      () => diContainer<Analytics>().setConsent(AnalyticsConsent.granted),
    );
    await tester.pump();

    expect(sink.screens, ['home', 'characters_list']);
    expect(sink.records.map((r) => r.seq), [1, 2, 3]);
  });

  testWidgets('T-0064-AC7 home, the quiz, a round, quit, back records home, '
      'trivia_setup, trivia_play, trivia_setup, home; a cold link to a round '
      'records trivia_play once, and Back the setup', (tester) async {
    await boot(tester);
    await tester.scrollUntilVisible(
      find.text('Trivia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Trivia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('trivia_setup.start')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey<String>('trivia_play.quit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mc_overlays.confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byKey(_home), findsOneWidget);

    expect(sink.screens, [
      'home',
      'trivia_setup',
      'trivia_play',
      'trivia_setup',
      'home',
    ]);
  });

  testWidgets('T-0064-AC7 a cold link to a round: the setup below it tracks '
      'nothing until Back shows it', (tester) async {
    await boot(
      tester,
      coldStartLink:
          'miniclient://app/trivia/play?category=all&difficulty=easy&seed=42',
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sink.screens, ['trivia_play']);
    await tester.tap(find.byKey(const ValueKey<String>('trivia_play.quit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mc_overlays.confirm')));
    await tester.pumpAndSettle();

    expect(sink.screens, ['trivia_play', 'trivia_setup']);
  });
}
