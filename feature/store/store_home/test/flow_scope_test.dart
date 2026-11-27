// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// initial category builds a new flow. The injected clock is what the deals
// count down against.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:store_home/store_home.dart';

import 'feature/util/store_home_env.dart';

void main() {
  setUpAll(bddSetUpAll);

  void serveStore() =>
      McTestSession.current.backend.useFixtureSet('commerce.default');

  Future<void> open(WidgetTester tester, {String? category}) async {
    await ensureStoreContainer();
    await initFlow(
      tester,
      () => storeTestHost(storeFlowUnderTest(category: category)),
    );
    await mcSettle(tester);
  }

  mcTestWidgets(
    "T-0056-AC8 the flow's container resolves every registration",
    (tester) async {
      serveStore();
      await open(tester);

      // The category page's bloc serves the open category, so open one.
      await tapIn(tester, 'categories', find.text('Heroes'));
      final page = tester.element(find.byKey(categoryGridKey));
      // Navigator, clock, API, repository and the six blocs.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  for (final missing in ['FeatureFlagsReader', 'AnalyticsTracker']) {
    mcTestWidgets('T-0056-AC8 a root without $missing fails naming it', (
      tester,
    ) async {
      final session = McTestSession.current;
      // A root with every forwarded type but [missing].
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<Monitoring>(session.monitoring)
            ..registerSingleton<SessionReader>(_NobodySignedIn());
          if (missing != 'FeatureFlagsReader') {
            getIt.registerSingleton<FeatureFlagsReader>(session.flags);
          }
          if (missing != 'AnalyticsTracker') {
            getIt.registerSingleton<AnalyticsTracker>(_NoTracker());
          }
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(session: session, home: storeTestHost(storeFlowUnderTest())),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<$missing>'));
      expect(find.byKey(storeHomeBodyKey), findsNothing);
    });
  }

  mcTestWidgets('T-0056-AC8 both pages use McAppBar with McFlowBackButton as '
      'leading', (tester) async {
    serveStore();
    await open(tester);
    var bar = tester.widget<McAppBar>(find.byType(McAppBar));
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Store');

    await tapIn(tester, 'categories', find.text('Heroes'));
    bar = tester.widget<McAppBar>(find.byType(McAppBar).last);
    expect(bar.leading, isA<McFlowBackButton>());
    expect(bar.title, 'Heroes');
    expect(
      find.descendant(
        of: find.byType(AppBar).last,
        matching: find.byType(BackButton),
      ),
      findsOneWidget,
      reason: 'the category page goes back inside the flow',
    );
  });

  mcTestWidgets('T-0056-AC5 a new initial category builds a new flow', (
    tester,
  ) async {
    serveStore();
    await ensureStoreContainer();
    final category = ValueNotifier<String>('heroes');
    addTearDown(category.dispose);
    await initFlow(
      tester,
      () => ValueListenableBuilder<String>(
        valueListenable: category,
        builder: (context, id, _) =>
            storeTestHost(storeFlowUnderTest(category: id)),
      ),
    );
    await mcSettle(tester);
    expect(storeFlowState(tester).root, 'heroes');
    expect(find.text('Heroes'), findsWidgets);

    category.value = 'cosmic';
    await mcSettle(tester);
    expect(storeFlowState(tester).root, 'cosmic');
    expect(find.text('Cosmic'), findsWidgets);
    expect(
      [
        for (final r in McTestSession.current.backend.requests)
          if (r.path.endsWith('/products')) r.path,
      ],
      [
        '/v1/store/categories/heroes/products',
        '/v1/store/categories/cosmic/products',
      ],
    );
  });

  Future<void> openAt(WidgetTester tester, Duration after) async {
    serveStore();
    await ensureStoreContainer();
    await initFlow(
      tester,
      () => storeTestHost(
        StoreHomeFlow(
          navigator: storeNavigator(),
          clock: () => defaultMockClock.add(after),
        ),
      ),
    );
    await mcSettle(tester);
  }

  String endsIn(WidgetTester tester, int product) {
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(dealKey(product)),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '');
    return texts.firstWhere((t) => t.startsWith('Ends'));
  }

  mcTestWidgets('T-0056-AC1 the deals count down against the injected clock, '
      'not the device time: 23 h and 1 h left end today, a deal at or after '
      'its end is left out (review round)', (tester) async {
    // The fixtures' deals end 1, 2, 3, ... 8 days after the fixed clock.
    // 25 h later: the first has ended, the second has 23 h left.
    await openAt(tester, const Duration(hours: 25));
    await scrollToSection(tester, 'deals');
    expect(find.byKey(dealKey(501501)), findsNothing, reason: 'ended');
    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(502240)));
    expect(endsIn(tester, 502240), 'Ends today');
    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(500822)));
    expect(endsIn(tester, 500822), 'Ends in 1 day');
  });

  mcTestWidgets('T-0056-AC1 exactly at a deal\'s end it is left out; an hour '
      'before, it ends today', (tester) async {
    await openAt(tester, const Duration(days: 2));
    await scrollToSection(tester, 'deals');
    expect(find.byKey(dealKey(501501)), findsNothing);
    expect(find.byKey(dealKey(502240)), findsNothing, reason: 'ends now');
    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(500822)));
    expect(endsIn(tester, 500822), 'Ends in 1 day');
  });

  mcTestWidgets('T-0056-AC1 an hour before the first deal ends, it ends '
      'today', (tester) async {
    await openAt(tester, const Duration(hours: 23));
    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(501501)));
    expect(endsIn(tester, 501501), 'Ends today');
  });

  mcTestWidgets('T-0056-AC1 when every deal has ended, the section is empty', (
    tester,
  ) async {
    await openAt(tester, const Duration(days: 8));
    await scrollToSection(tester, 'deals');
    expect(find.byKey(sectionPartKey('deals', 'empty')), findsOneWidget);
    expect(find.text('No deals right now.'), findsOneWidget);
  });

  mcTestWidgets('T-0056-AC7 a store page built under another screen loads and '
      'tracks nothing until it is shown; then each section loads and is viewed '
      'once, and covering it again changes nothing (one visit, review round)', (
    tester,
  ) async {
    serveStore();
    await ensureStoreContainer();
    final session = McTestSession.current;
    await tester.pumpWidget(
      McTestApp(session: session, home: storeTestHost(storeFlowUnderTest())),
    );
    // A screen over the store before the store page is built.
    final navigator = Navigator.of(tester.element(find.byType(StoreHomeFlow)));
    Future<void> cover() => navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('cover')),
      ),
    );
    unawaited(cover());
    await mcSettle(tester);

    int requests(String path) => session.backend.requests
        .where((r) => r.method == 'GET' && r.path == path)
        .length;
    const store = [
      '/v1/store/banners',
      '/v1/store/deals',
      '/v1/store/categories',
      '/v1/store/featured',
    ];
    List<String> viewed() => [
      for (final e in session.analytics.events)
        if (e.name == 'store_section_viewed') e.params['section']! as String,
    ];
    expect(find.text('cover'), findsOneWidget);
    expect(find.byKey(storeHomeBodyKey, skipOffstage: false), findsOneWidget);
    expect([for (final p in store) requests(p)], [0, 0, 0, 0]);
    expect(viewed(), isEmpty);

    navigator.pop();
    await mcSettle(tester);
    expect([for (final p in store) requests(p)], [1, 1, 1, 1]);
    expect(viewed()..sort(), ['banners', 'categories', 'deals', 'featured']);

    unawaited(cover());
    await mcSettle(tester);
    navigator.pop();
    await mcSettle(tester);
    expect([for (final p in store) requests(p)], [1, 1, 1, 1]);
    expect(viewed(), hasLength(4), reason: 'one visit');
  });
}

class _NobodySignedIn implements SessionReader {
  @override
  AuthStatus get status => AuthStatus.signedOut;
  @override
  bool get isSignedIn => false;
  @override
  String? get userId => null;
  @override
  String? get accessToken => null;
  @override
  String? get refreshToken => null;
  @override
  int get epoch => 0;
  @override
  Stream<AuthStatus> get authState => const Stream.empty();
}

class _NoTracker implements AnalyticsTracker {
  @override
  void trackEvent(String name, [Map<String, Object> params = const {}]) {}
  @override
  void trackScreen(String name) {}
}
