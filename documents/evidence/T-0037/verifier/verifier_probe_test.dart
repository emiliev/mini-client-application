// T-0037 Verifier probes (temporary, not committed as a test; a copy is kept
// as evidence). Real GoRouter, real deep link, LocalHistoryEntry, isFirst vs
// canPop, AC2 outside a flow.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

class _S {
  const _S();
}

/// Records every build of the flow root page, so a probe can prove the page
/// itself was not rebuilt (only the button's own dependencies).
int rootBuilds = 0;

class _Root extends StatelessWidget {
  const _Root({this.drawer = false});
  final bool drawer;

  @override
  Widget build(BuildContext context) {
    rootBuilds++;
    return Scaffold(
      drawer: drawer ? const Drawer() : null,
      appBar: AppBar(
        leading: const McFlowBackButton(),
        title: const Text('vroot'),
      ),
      body: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        onPressed: () => Scaffold.of(context).showBottomSheet(
          (_) => const SizedBox(height: 80, child: Text('vsheet')),
        ),
        child: const Text('vshow sheet'),
      ),
      TextButton(
        onPressed: () => ModalRoute.of(context)!.addLocalHistoryEntry(
          LocalHistoryEntry(onRemove: () => removed++),
        ),
        child: const Text('vadd entry'),
      ),
    ],
  );
}

int removed = 0;

FeatureFlow<_S> vflow({bool drawer = false}) => FeatureFlow<_S>(
  state: const _S(),
  onGeneratePages: (_) => [
    McFlowPage(
      name: 'root',
      child: _Root(drawer: drawer),
    ),
  ],
);

Finder get back => find.byType(BackButton);

Future<void> pushLink(WidgetTester tester, String location) =>
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

GoRouter router({required bool sameInstance, String initial = '/characters'}) {
  final shared = vflow();
  Page<void> flowPage(BuildContext c, GoRouterState s) => MaterialPage<void>(
    key: const ValueKey<String>('flow'),
    child: sameInstance ? shared : vflow(),
  );
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/characters', pageBuilder: flowPage),
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('vhome')),
        routes: [GoRoute(path: 'list', pageBuilder: flowPage)],
      ),
    ],
  );
}

Future<GoRouter> mount(
  WidgetTester tester, {
  required bool sameInstance,
  String initial = '/characters',
}) async {
  final r = router(sameInstance: sameInstance, initial: initial);
  addTearDown(r.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: McTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: r,
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

void main() {
  setUp(() => rootBuilds = 0);

  for (final same in [true, false]) {
    final tag = same ? 'same flow instance' : 'new flow instance each build';
    testWidgets('VP1 GoRouter go [flow] -> [home, flow] same page key ($tag)', (
      tester,
    ) async {
      final r = await mount(tester, sameInstance: same);
      expect(find.text('vroot'), findsOneWidget);
      expect(back, findsNothing);
      final state = tester.state(find.byType(FeatureFlow<_S>));
      final builds = rootBuilds;

      r.go('/list');
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(FeatureFlow<_S>)),
        same ? state : state,
        reason: 'same FeatureFlow state: route kept',
      );
      expect(rootBuilds, builds, reason: 'the root page was not rebuilt');
      expect(back, findsOneWidget);

      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('vroot'), findsNothing);
      expect(find.text('vhome'), findsOneWidget);
    });

    testWidgets('VP2 GoRouter go [home, flow] -> [flow] same key ($tag)', (
      tester,
    ) async {
      final r = await mount(tester, sameInstance: same, initial: '/list');
      expect(back, findsOneWidget);
      final state = tester.state(find.byType(FeatureFlow<_S>));
      r.go('/characters');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FeatureFlow<_S>)), state);
      expect(back, findsNothing);
    });

    testWidgets('VP3 deep link via flutter/navigation [flow] -> [home, flow] '
        '($tag)', (tester) async {
      await mount(tester, sameInstance: same);
      expect(back, findsNothing);
      final state = tester.state(find.byType(FeatureFlow<_S>));
      await pushLink(tester, '/list');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FeatureFlow<_S>)), state);
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('vhome'), findsOneWidget);
    });

    testWidgets('VP4 deep link via flutter/navigation [home, flow] -> [flow] '
        '($tag)', (tester) async {
      await mount(tester, sameInstance: same, initial: '/list');
      expect(back, findsOneWidget);
      await pushLink(tester, 'miniclient://app/characters');
      await tester.pumpAndSettle();
      expect(find.text('vroot'), findsOneWidget);
      expect(back, findsNothing);
    });
  }

  Future<BuildContext> openPushed(WidgetTester tester, Widget flow) async {
    late BuildContext home;
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.light,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            home = context;
            return Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push<void>(MaterialPageRoute(builder: (_) => flow)),
                child: const Text('vopen'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('vopen'));
    await tester.pumpAndSettle();
    return home;
  }

  testWidgets('VP5 pushed flow, then removeRouteBelow(flow): button goes', (
    tester,
  ) async {
    final home = await openPushed(tester, vflow());
    expect(back, findsOneWidget);
    final flowCtx = tester.element(find.byType(FeatureFlow<_S>));
    final nav = Navigator.of(home);
    nav.removeRouteBelow(ModalRoute.of(flowCtx)!);
    await tester.pumpAndSettle();
    expect(find.text('vroot'), findsOneWidget);
    expect(back, findsNothing);
  });

  testWidgets('VP6 pushAndRemoveUntil a flow with nothing kept below: no '
      'button after the transition', (tester) async {
    final home = await openPushed(tester, const Text('first page'));
    Navigator.of(home).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => vflow()),
      (_) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final mid = back.evaluate().length;
    await tester.pumpAndSettle();
    expect(find.text('vroot'), findsOneWidget);
    expect(back, findsNothing, reason: 'mid-transition count was $mid');
  });

  testWidgets('VP7 pushed flow then [home] removed by pushAndRemoveUntil of '
      'a route that is popped later (flow first again)', (tester) async {
    // [home, flow] -> pushAndRemoveUntil(X, keep flow) -> [flow, X]? no:
    // pushAndRemoveUntil keeps routes from the predicate down. Instead
    // replace home under the flow: replaceRouteBelow.
    final home = await openPushed(tester, vflow());
    expect(back, findsOneWidget);
    final flowCtx = tester.element(find.byType(FeatureFlow<_S>));
    Navigator.of(home).replaceRouteBelow<void>(
      anchorRoute: ModalRoute.of(flowCtx)!,
      newRoute: MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('vnew home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(back, findsOneWidget, reason: 'still a route below');
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('vnew home'), findsOneWidget);
  });

  group('isFirst vs canPop', () {
    testWidgets('VP8 app-root flow whose outer route has a local history '
        'entry: outer.canPop() is true, !isFirst false, button hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: vflow(),
        ),
      );
      await tester.pumpAndSettle();
      final flowCtx = tester.element(find.byType(FeatureFlow<_S>));
      ModalRoute.of(flowCtx)!.addLocalHistoryEntry(LocalHistoryEntry());
      await tester.pumpAndSettle();
      expect(Navigator.of(flowCtx).canPop(), isTrue, reason: 'canPop() says yes');
      expect(ModalRoute.of(flowCtx)!.isFirst, isTrue);
      expect(back, findsNothing, reason: 'nothing below the flow to go to');
    });

    testWidgets('VP9 app-root flow with a dialog route above it in the outer '
        'navigator: outer.canPop() true, isFirst true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: vflow(),
        ),
      );
      await tester.pumpAndSettle();
      final flowCtx = tester.element(find.byType(FeatureFlow<_S>));
      unawaited(
        showGeneralDialog<void>(
          context: flowCtx,
          barrierDismissible: false,
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      expect(Navigator.of(flowCtx).canPop(), isTrue);
      expect(back, findsNothing);
    });

    testWidgets('VP10 edge: pushed flow, outer route holds a local history '
        'entry, then the route below is removed: is the button stale?', (
      tester,
    ) async {
      final home = await openPushed(tester, vflow());
      expect(back, findsOneWidget);
      final flowCtx = tester.element(find.byType(FeatureFlow<_S>));
      ModalRoute.of(flowCtx)!.addLocalHistoryEntry(LocalHistoryEntry());
      await tester.pumpAndSettle();
      Navigator.of(home).removeRoute(ModalRoute.of(home)!);
      await tester.pumpAndSettle();
      expect(ModalRoute.of(flowCtx)!.isFirst, isTrue);
      final scope = tester.widget<FlowScope>(find.byType(FlowScope));
      // Record, not assert: the result goes to the report.
      debugPrint(
        'VP10 RESULT outerCanPop=${scope.outerCanPop} '
        'backButtons=${back.evaluate().length}',
      );
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back);
        await tester.pumpAndSettle();
        final after = tester.widget<FlowScope>(find.byType(FlowScope));
        debugPrint(
          'VP10 AFTER TAP still in flow=${find.text('vroot').evaluate().length} '
          'outerCanPop=${after.outerCanPop} '
          'backButtons=${back.evaluate().length}',
        );
      }
    });
  });

  group('AC3 precedence with a LocalHistoryEntry', () {
    testWidgets('VP11 pushed flow, LocalHistoryEntry on the root page: '
        'BackButton removes the entry and stays in the flow', (tester) async {
      removed = 0;
      await openPushed(tester, vflow());
      expect(back, findsOneWidget);
      await tester.tap(find.text('vadd entry'));
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(removed, 1, reason: 'the entry was removed');
      expect(find.text('vroot'), findsOneWidget, reason: 'still in the flow');
      expect(find.text('vopen'), findsNothing);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('vopen'), findsOneWidget, reason: 'now it leaves');
    });

    testWidgets('VP12 drawer + LocalHistoryEntry on a pushed root: the entry '
        'wins (BackButton, not DrawerButton)', (tester) async {
      removed = 0;
      await openPushed(tester, vflow(drawer: true));
      expect(find.byType(DrawerButton), findsOneWidget);
      await tester.tap(find.text('vadd entry'));
      await tester.pumpAndSettle();
      expect(find.byType(DrawerButton), findsNothing);
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(removed, 1);
      expect(find.text('vroot'), findsOneWidget);
      expect(find.byType(DrawerButton), findsOneWidget);
    });

    testWidgets('VP13 app-root flow with a LocalHistoryEntry: BackButton, '
        'which removes it', (tester) async {
      removed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: vflow(),
        ),
      );
      await tester.pumpAndSettle();
      expect(back, findsNothing);
      await tester.tap(find.text('vadd entry'));
      await tester.pumpAndSettle();
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(removed, 1);
      expect(back, findsNothing);
    });

    testWidgets('VP14 real showBottomSheet on a pushed root, no drawer: back '
        'closes the sheet, stays in the flow', (tester) async {
      await openPushed(tester, vflow());
      await tester.tap(find.text('vshow sheet'));
      await tester.pumpAndSettle();
      expect(find.text('vsheet'), findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('vsheet'), findsNothing);
      expect(find.text('vroot'), findsOneWidget);
      expect(find.text('vopen'), findsNothing);
    });
  });

  testWidgets('VP18 design note: a nested (non-flow) Navigator on the flow\'s '
      'second page; its first route\'s button', (tester) async {
    late FeatureFlowController<int> c;
    await openPushed(
      tester,
      FeatureFlow<int>(
        state: 0,
        onGeneratePages: (s) => [
          McFlowPage(
            name: 'root',
            child: Builder(
              builder: (context) {
                c = context.di<FeatureFlowController<int>>();
                return const Scaffold(body: Text('vpage1'));
              },
            ),
          ),
          if (s > 0)
            McFlowPage(
              name: 'two',
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      leading: const McFlowBackButton(),
                      title: const Text('vnested'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    c.update((_) => 1);
    await tester.pumpAndSettle();
    expect(find.text('vnested'), findsOneWidget);
    final n = back.evaluate().length;
    if (n > 0) {
      await tester.tap(back.first);
      await tester.pumpAndSettle();
    }
    debugPrint(
      'VP18 RESULT backButtons=$n after tap: page1=${find.text('vpage1').evaluate().length} '
      'nested=${find.text('vnested').evaluate().length} '
      'home=${find.text('vopen').evaluate().length}',
    );
  });

  group('AC2 outside a flow', () {
    Widget page({bool drawer = false}) => Scaffold(
      drawer: drawer ? const Drawer() : null,
      appBar: AppBar(leading: const McFlowBackButton(), title: const Text('p')),
      body: const Text('vpage'),
    );

    testWidgets('VP15 first route, no flow, no drawer: empty, no error', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: page()));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(McFlowBackButton),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('VP16 first route, no flow, drawer: DrawerButton opens it', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: page(drawer: true)));
      expect(tester.takeException(), isNull);
      expect(find.byType(DrawerButton), findsOneWidget);
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets('VP17 pushed route, no flow: automatic back pops it; '
        'fullscreen dialog gets CloseButton', (tester) async {
      late BuildContext home;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              home = c;
              return const Text('vhome');
            },
          ),
        ),
      );
      unawaited(
        Navigator.of(home).push<void>(MaterialPageRoute(builder: (_) => page())),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('vpage'), findsNothing);
      unawaited(
        Navigator.of(home).push<void>(
          MaterialPageRoute(builder: (_) => page(), fullscreenDialog: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CloseButton), findsOneWidget);
    });
  });
}

void unawaited(Future<void>? f) {}
