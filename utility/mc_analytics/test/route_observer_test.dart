// T-0053-AC4: screen tracking with a real GoRouter (push, pop, go, replace,
// dialogs ignored) and with a plain Navigator.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_analytics/mc_analytics.dart';

import 'support.dart';

Widget _page(String title, [List<Widget> actions = const []]) => Scaffold(
  body: Column(children: [Text(title), ...actions]),
);

void main() {
  late Rig rig;

  setUp(() => rig = Rig());

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      observers: [AnalyticsRouteObserver(rig.analytics)],
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, _) => _page('Home', [
            TextButton(
              onPressed: () => context.push('/list'),
              child: const Text('open list'),
            ),
            TextButton(
              onPressed: () => context.go('/list'),
              child: const Text('go list'),
            ),
            TextButton(
              onPressed: () => context.push('/unnamed'),
              child: const Text('open unnamed'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('A dialog')),
              ),
              child: const Text('open dialog'),
            ),
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 100, child: Text('Sheet')),
              ),
              child: const Text('open sheet'),
            ),
            TextButton(
              onPressed: () => context.pushReplacement('/list'),
              child: const Text('replace with list'),
            ),
          ]),
          routes: [
            GoRoute(
              path: 'detail',
              name: 'detail_page',
              builder: (_, _) => _page('Detail'),
            ),
          ],
        ),
        GoRoute(
          path: '/list',
          name: 'characters_list',
          builder: (context, _) => _page('List', [
            TextButton(
              onPressed: () => context.push('/'),
              child: const Text('open home'),
            ),
          ]),
        ),
        // No name: go_router names the page by its path, which is not a
        // screen name.
        GoRoute(
          path: '/unnamed',
          builder: (context, _) => _page('Unnamed', [
            TextButton(
              onPressed: () => context.push('/list'),
              child: const Text('open list'),
            ),
          ]),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  Future<List<String>> screens(WidgetTester tester) async {
    await tester.pump();
    return rig.sink.screens;
  }

  testWidgets('T-0053-AC4 the first page is tracked', (tester) async {
    await pumpRouter(tester);

    expect(await screens(tester), ['home']);
  });

  testWidgets('T-0053-AC4 push then pop records home, list, home', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    await tap(tester, 'open list');
    router.pop();
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home', 'characters_list', 'home']);
  });

  testWidgets('T-0053-AC4 go replaces the stack and tracks the target once', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tap(tester, 'go list');

    expect(await screens(tester), ['home', 'characters_list']);
  });

  testWidgets('T-0053-AC4 a nested page, then back to its parent', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    unawaited(router.push('/detail'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home', 'detail_page', 'home']);
  });

  testWidgets('T-0053-AC4 a replacement tracks the new page', (tester) async {
    await pumpRouter(tester);

    await tap(tester, 'replace with list');

    expect(await screens(tester), ['home', 'characters_list']);
  });

  testWidgets('T-0053-AC4 a dialog is ignored, opening and closing it', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    await tap(tester, 'open dialog');
    expect(find.text('A dialog'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('A dialog'), findsNothing);

    expect(await screens(tester), ['home'], reason: 'no repeat after close');
  });

  testWidgets('T-0053-AC4 a bottom sheet is ignored too', (tester) async {
    await pumpRouter(tester);

    await tap(tester, 'open sheet');
    expect(find.text('Sheet'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home']);
  });

  testWidgets('T-0053-AC4 a dialog over a pushed page does not repeat it', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    await tap(tester, 'open list');
    final context = tester.element(find.text('List'));

    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Over list')),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(context, rootNavigator: true).pop();
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home', 'characters_list']);
    expect(router.state.uri.path, '/list');
  });

  testWidgets('T-0053-AC4 an unnamed page is not tracked, but coming back '
      'to the page below is', (tester) async {
    final router = await pumpRouter(tester);

    await tap(tester, 'open unnamed');
    expect(await screens(tester), ['home'], reason: 'the path is no name');
    router.pop();
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home', 'home']);
  });

  testWidgets('T-0053-AC4 pushing the same screen twice tracks it twice', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tap(tester, 'open list');
    await tap(tester, 'open home');
    await tap(tester, 'open list');

    expect(await screens(tester), [
      'home',
      'characters_list',
      'home',
      'characters_list',
    ]);
  });

  testWidgets('T-0053-AC4 a rebuild with no route change tracks nothing', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(await screens(tester), ['home']);
  });

  group('T-0053-AC4 with a plain Navigator', () {
    Route<void> named(String? name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => Text(name ?? 'anonymous'),
    );

    testWidgets('T-0053-AC4 push, pop, replace and remove', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [AnalyticsRouteObserver(rig.analytics)],
          onGenerateRoute: (settings) => named(settings.name),
          initialRoute: 'home',
        ),
      );
      await tester.pumpAndSettle();
      final nav = key.currentState!;

      unawaited(nav.push(named('a_page')));
      await tester.pumpAndSettle();
      unawaited(nav.pushReplacement(named('b_page')));
      await tester.pumpAndSettle();
      unawaited(nav.pushAndRemoveUntil(named('c_page'), (_) => false));
      await tester.pumpAndSettle();

      expect(await screens(tester), ['home', 'a_page', 'b_page', 'c_page']);
    });

    testWidgets('T-0053-AC4 names that are not screen names are skipped', (
      tester,
    ) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: [AnalyticsRouteObserver(rig.analytics)],
          onGenerateRoute: (settings) => named(settings.name),
          initialRoute: 'home',
        ),
      );
      await tester.pumpAndSettle();
      final nav = key.currentState!;

      for (final bad in [null, '', '/search', 'Not A Name', 'x' * 41]) {
        unawaited(nav.push(named(bad)));
        await tester.pumpAndSettle();
      }

      // No AssertionError either: the observer never passes a bad name on.
      expect(await screens(tester), ['home']);
    });
  });

  test('T-0053-AC4 a lazy observer looks Analytics up at the first screen, '
      'not when it is made', () async {
    var lookups = 0;
    final observer = AnalyticsRouteObserver.lazy(() {
      lookups++;
      return rig.analytics;
    });
    Route<void> route(String? name) => MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox(),
    );

    expect(lookups, 0);
    observer.didChangeTop(route(null), null);
    observer.didChangeTop(route('/path'), null);
    expect(lookups, 0, reason: 'nothing to track yet');
    observer.didChangeTop(route('home'), null);
    await settle();

    expect(lookups, 1);
    expect(rig.sink.screens, ['home']);
  });
}
