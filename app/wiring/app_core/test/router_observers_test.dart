// T-0053-AC4: the app router's analytics observers never break navigation, and
// only the router's declared names are screens.
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

Widget _page(String text) => Scaffold(body: Text(text));

GoRouter _router(List<NavigatorObserver> Function(GoRouter Function()) make) {
  late final GoRouter router;
  router = GoRouter(
    observers: make(() => router),
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, _) => _page('Home'),
        routes: [
          GoRoute(path: 'settings', builder: (_, _) => _page('Settings')),
          GoRoute(
            path: 'profile',
            name: 'profile_page',
            builder: (_, _) => _page('Profile'),
          ),
        ],
      ),
    ],
  );
  return router;
}

void main() {
  setUp(resetDIContainer);
  tearDown(resetDIContainer);

  testWidgets('T-0053-AC4 with no Analytics registered, navigating works', (
    tester,
  ) async {
    expect(diContainer.isRegistered<Analytics>(), isFalse);
    final router = _router(
      (r) => appRouterObservers(
        screenNames: () => goRouteNames(r().configuration.routes),
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0053-AC4 goRouteNames lists every declared name, nested too', (
    tester,
  ) async {
    final router = _router((_) => const []);
    addTearDown(router.dispose);

    expect(goRouteNames(router.configuration.routes), {
      'home',
      'profile_page',
    });
  });

  testWidgets('T-0053-AC4 with Analytics registered only declared names are '
      'screens', (tester) async {
    final sink = InMemoryAnalyticsSink();
    final analytics = Analytics(
      sinks: [sink],
      monitoring: Monitoring(const []),
      consent: AnalyticsConsent.granted,
      debugMode: true,
    );
    await initializeDIContainer([
      McDIInitializer((g, _) => g.registerSingleton<Analytics>(analytics)),
    ]);
    final router = _router(
      (r) => appRouterObservers(
        screenNames: () => goRouteNames(r().configuration.routes),
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    unawaited(router.push('/settings'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    unawaited(router.push('/profile'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(sink.screens, ['home', 'home', 'profile_page']);
  });
}
