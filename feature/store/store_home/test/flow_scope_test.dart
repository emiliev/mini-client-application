// The flow as a unit of wiring, entered through the barrel only. R17: its
// hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a
// missing one fails at flow creation, naming the type (`mcgen wire` will
// generate the list, Phase D). The flow is immutable after creation: a new
// initial category builds a new flow. The injected clock is what the deals
// count down against.
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

  mcTestWidgets('T-0056-AC1 the deals count down against the injected clock, '
      'not the device time', (tester) async {
    serveStore();
    await ensureStoreContainer();
    await initFlow(
      tester,
      () => storeTestHost(
        StoreHomeFlow(
          navigator: storeNavigator(),
          // A day and an hour after the fixtures' clock: the first deal (1
          // day) has ended, the second (2 days) ends in 23 hours.
          clock: () => defaultMockClock.add(const Duration(hours: 25)),
        ),
      ),
    );
    await mcSettle(tester);

    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(501501)));
    expect(
      find.descendant(
        of: find.byKey(dealKey(501501)),
        matching: find.text('Ends today'),
      ),
      findsOneWidget,
    );
    await scrollCarouselTo(tester, 'deals', find.byKey(dealKey(502240)));
    expect(
      find.descendant(
        of: find.byKey(dealKey(502240)),
        matching: find.text('Ends in 1 day'),
      ),
      findsOneWidget,
    );
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
