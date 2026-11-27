// T-0056-AC7 (P-103): the pages inside a feature flow are tracked as
// screens by an AnalyticsFlowObserver on the flow's own navigator, together
// with the app's AnalyticsRouteObserver. The "flow" here is a plain nested
// Navigator whose pages follow a notifier, which is what FeatureFlow builds.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_analytics/mc_analytics.dart';

import 'support.dart';

/// A nested navigator with a first page [first] and, while [category] holds
/// a value, a second page `store_category` above it.
class _Flow extends StatelessWidget {
  const _Flow({
    required this.observer,
    required this.category,
    this.first = 'store_home',
  });

  final NavigatorObserver observer;
  final ValueNotifier<bool> category;
  final String first;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: category,
    builder: (context, open, _) => Navigator(
      observers: [observer],
      pages: [
        MaterialPage<void>(
          name: first,
          key: ValueKey(first),
          child: const Scaffold(body: Text('flow home')),
        ),
        if (open)
          const MaterialPage<void>(
            name: 'store_category',
            key: ValueKey('store_category'),
            child: Scaffold(body: Text('flow category')),
          ),
      ],
      onDidRemovePage: (page) {
        if (page.name == 'store_category') {
          category.value = false;
        }
      },
    ),
  );
}

void main() {
  late Rig rig;
  late ValueNotifier<bool> category;

  setUp(() {
    rig = Rig();
    category = ValueNotifier(false);
  });
  tearDown(() => category.dispose());

  AnalyticsFlowObserver flowObserver() =>
      AnalyticsFlowObserver((_) => rig.analytics);

  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    String first = 'store_home',
  }) async {
    final observer = flowObserver();
    final router = GoRouter(
      initialLocation: '/',
      observers: [AnalyticsRouteObserver(rig.analytics)],
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/store',
          name: 'store_home',
          builder: (_, _) =>
              _Flow(observer: observer, category: category, first: first),
        ),
        GoRoute(
          path: '/comic',
          name: 'comics_details',
          builder: (_, _) => const Scaffold(body: Text('comic')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<List<String>> screens(WidgetTester tester) async {
    await tester.pump();
    return rig.sink.screens;
  }

  testWidgets(
    'T-0056-AC7 store, category, back: the flow\'s first page is '
    'not tracked twice, its pushed page is, and Back tracks the first again',
    (
      tester,
    ) async {
      final router = await pumpApp(tester);
      unawaited(router.push('/store'));
      await tester.pumpAndSettle();
      expect(await screens(tester), ['home', 'store_home']);

      category.value = true;
      await tester.pumpAndSettle();
      expect(find.text('flow category'), findsOneWidget);
      Navigator.of(tester.element(find.text('flow category'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('flow home'), findsOneWidget);

      expect(await screens(tester), [
        'home',
        'store_home',
        'store_category',
        'store_home',
      ]);
    },
  );

  testWidgets('T-0056-AC7 coming back to the route tracks the page its flow '
      'shows, not the route\'s name', (tester) async {
    final router = await pumpApp(tester);
    unawaited(router.push('/store'));
    await tester.pumpAndSettle();
    category.value = true;
    await tester.pumpAndSettle();

    unawaited(router.push('/comic'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('flow category'), findsOneWidget);

    expect(await screens(tester), [
      'home',
      'store_home',
      'store_category',
      'comics_details',
      'store_category',
    ]);
  });

  testWidgets('T-0056-AC7 a page the flow changes while another screen is on '
      'top is tracked when the route comes back, once', (tester) async {
    final router = await pumpApp(tester);
    unawaited(router.push('/store'));
    await tester.pumpAndSettle();
    unawaited(router.push('/comic'));
    await tester.pumpAndSettle();

    category.value = true;
    await tester.pumpAndSettle();
    expect(await screens(tester), ['home', 'store_home', 'comics_details']);

    router.pop();
    await tester.pumpAndSettle();
    expect(await screens(tester), [
      'home',
      'store_home',
      'comics_details',
      'store_category',
    ]);
  });

  testWidgets('T-0056-AC7 a first page named unlike its route is tracked '
      'too (name the first page as the route)', (tester) async {
    final router = await pumpApp(tester, first: 'store_front');
    unawaited(router.push('/store'));
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home', 'store_home', 'store_front']);
  });

  testWidgets('T-0056-AC7 outside an observed route the first page is '
      'tracked, then each change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Flow(observer: flowObserver(), category: category),
      ),
    );
    await tester.pumpAndSettle();
    category.value = true;
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('flow category'))).pop();
    await tester.pumpAndSettle();

    expect(await screens(tester), [
      'store_home',
      'store_category',
      'store_home',
    ]);
  });

  testWidgets('T-0056-AC7 popups inside the flow are ignored, unnamed and '
      'invalid page names are not tracked, and no Analytics tracks nothing', (
    tester,
  ) async {
    Widget nested(String key, String? name, {bool silent = false}) => Navigator(
      key: ValueKey(key),
      observers: [
        AnalyticsFlowObserver((_) => silent ? null : rig.analytics),
      ],
      pages: [MaterialPage<void>(name: name, child: Text('page $key'))],
      onDidRemovePage: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Expanded(child: nested('a', 'Not Valid')),
            Expanded(child: nested('b', null)),
            Expanded(child: nested('c', 'valid_page', silent: true)),
            Expanded(child: nested('d', 'shown_page')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await screens(tester), ['shown_page']);

    unawaited(
      showDialog<void>(
        context: tester.element(find.text('page d')),
        useRootNavigator: false,
        builder: (_) => const AlertDialog(title: Text('popup')),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('popup'))).pop();
    await tester.pumpAndSettle();

    expect(
      await screens(tester),
      ['shown_page'],
      reason: 'the popup is ignored and the page is not tracked again',
    );
  });
}
