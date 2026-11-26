import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

import 'navigation_channel_support.dart';

class _State {
  const _State();
}

/// A flow root page, const so that nothing but the button's own dependencies
/// can rebuild it. [drawer] gives its Scaffold a drawer; its body has a button
/// that shows a persistent bottom sheet (a local history entry).
class _Root extends StatelessWidget {
  const _Root({this.drawer = false});

  final bool drawer;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: drawer ? const Drawer() : null,
    appBar: AppBar(
      leading: const McFlowBackButton(),
      title: const Text('flow root'),
    ),
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => Scaffold.of(context).showBottomSheet<void>(
          (_) => const SizedBox(height: 80, child: Text('sheet')),
        ),
        child: const Text('show sheet'),
      ),
    ),
  );
}

FeatureFlow<_State> _flow({bool drawer = false}) => FeatureFlow<_State>(
  state: const _State(),
  onGeneratePages: (_) => [McFlowPage(name: 'root', child: _Root(drawer: drawer))],
);

Widget _app(Widget home) => MaterialApp(
  theme: McTheme.light,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

/// The outer navigator of a router-like host: pages are named, so a test can
/// rebuild the stack while the flow keeps its page key (what a router `go` or
/// a deep link does).
class _Host extends StatelessWidget {
  const _Host({required this.pages, required this.flow});

  final ValueNotifier<List<String>> pages;
  final Widget flow;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<String>>(
    valueListenable: pages,
    builder: (context, names, _) => Navigator(
      pages: [
        for (final name in names)
          MaterialPage<void>(
            key: ValueKey<String>(name),
            child: name == 'flow'
                ? flow
                : const Scaffold(body: Center(child: Text('home page'))),
          ),
      ],
      onDidRemovePage: (page) => pages.value = [
        for (final name in pages.value)
          if (ValueKey<String>(name) != page.key) name,
      ],
    ),
  );
}

Future<void> _openFlow(WidgetTester tester, Widget flow) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => flow)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('flow root'), findsOneWidget);
}

void main() {
  group('T-0037-AC1 the button follows the routes below the flow', () {
    testWidgets('T-0037-AC1 a rebuilt stack [home, flow] under the same flow '
        'page key shows the button, which pops back home', (tester) async {
      final pages = ValueNotifier<List<String>>(['flow']);
      await tester.pumpWidget(
        _app(_Host(pages: pages, flow: _flow())),
      );
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);

      pages.value = ['home', 'flow'];
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsOneWidget, reason: 'same flow');
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsNothing);
      expect(find.text('home page'), findsOneWidget);
    });

    testWidgets('T-0037-AC1 removing the routes below a pushed flow (page '
        'stack) removes the button', (tester) async {
      final pages = ValueNotifier<List<String>>(['home', 'flow']);
      await tester.pumpWidget(
        _app(_Host(pages: pages, flow: _flow())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      pages.value = ['flow'];
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0037-AC1 removing the route below a pushed flow '
        '(removeRoute) removes the button', (tester) async {
      late BuildContext home;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              home = context;
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => _flow()),
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      Navigator.of(home).removeRoute(ModalRoute.of(home)!);
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });

  group('T-0037-AC2 outside any FeatureFlow', () {
    Widget page({bool drawer = false}) => Scaffold(
      drawer: drawer ? const Drawer() : null,
      appBar: AppBar(leading: const McFlowBackButton(), title: const Text('p')),
    );

    testWidgets('T-0037-AC2 a first route without a drawer builds empty, '
        'without an error', (tester) async {
      await tester.pumpWidget(_app(page()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(DrawerButton), findsNothing);
      final own = find.descendant(
        of: find.byType(McFlowBackButton),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(own), Size.zero);
    });

    testWidgets('T-0037-AC2 a first route with a drawer shows the '
        'DrawerButton', (tester) async {
      await tester.pumpWidget(_app(page(drawer: true)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DrawerButton), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0037-AC2 a pushed route outside a flow keeps the '
        'automatic back button', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute(builder: (_) => page())),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('T-0037-AC3 precedence on the flow root', () {
    testWidgets('T-0037-AC3 a local history entry wins: back removes the '
        'sheet and stays in the flow', (tester) async {
      await _openFlow(tester, _flow(drawer: true));
      expect(find.byType(DrawerButton), findsOneWidget, reason: 'no entry yet');

      await tester.tap(find.text('show sheet'));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
      expect(find.byType(DrawerButton), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('flow root'), findsOneWidget, reason: 'still in flow');
      expect(find.text('open'), findsNothing);
      expect(find.byType(DrawerButton), findsOneWidget);
    });

    testWidgets('T-0037-AC3 a local history entry shows the button even when '
        'the flow is the app root', (tester) async {
      await tester.pumpWidget(_app(_flow()));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);

      await tester.tap(find.text('show sheet'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
      expect(find.text('flow root'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0037-AC3 a drawer on a pushed flow root shows the '
        'DrawerButton, not the back button', (tester) async {
      await _openFlow(tester, _flow(drawer: true));

      expect(find.byType(DrawerButton), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0037-AC3 a drawer on a flow that is the app root shows '
        'the DrawerButton', (tester) async {
      await tester.pumpWidget(_app(_flow(drawer: true)));
      await tester.pumpAndSettle();

      expect(find.byType(DrawerButton), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0037-AC3 otherwise the flow back button shows and leaves '
        'the flow', (tester) async {
      await _openFlow(tester, _flow());

      expect(find.byType(DrawerButton), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('T-0037-AC3 the root button respects the outer route\'s '
        'PopScope', (tester) async {
      final invoked = <bool>[];
      await _openFlow(
        tester,
        PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => invoked.add(didPop),
          child: _flow(),
        ),
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(invoked, [false], reason: 'the PopScope was asked');
      expect(find.text('flow root'), findsOneWidget, reason: 'it said no');
      expect(find.text('open'), findsNothing);
    });

    testWidgets('T-0037-AC3 flow_builder keeps one PopScope mounted whatever '
        'its canPop', (tester) async {
      final state = ValueNotifier<int>(0);
      await _openFlow(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: state,
          builder: (context, value, _) => FlowBuilder<int>(
            state: value,
            onGeneratePages: (s, _) => [
              const MaterialPage<void>(child: _Root()),
              if (s > 0)
                const MaterialPage<void>(
                  child: Scaffold(body: Text('detail')),
                ),
            ],
          ),
        ),
      );
      final scope = find.descendant(
        of: find.byType(FlowBuilder<int>),
        matching: find.byType(PopScope<Object?>),
      );
      expect(scope, findsOneWidget, reason: 'one page, outer route below');
      expect(tester.widget<PopScope<Object?>>(scope).canPop, isFalse);

      state.value = 1;
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(scope, findsOneWidget);
      expect(tester.widget<PopScope<Object?>>(scope).canPop, isFalse);

      state.value = 0;
      await tester.pumpAndSettle();
      expect(scope, findsOneWidget);
    });
  });

  group('T-0037-AC4 flow_builder and the gates', () {
    testWidgets('T-0037-AC4 a FlowBuilder driven by state from its parent '
        'accepts the next pop after two pages become one', (tester) async {
      final state = ValueNotifier<int>(1);
      await _openFlow(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: state,
          builder: (context, value, _) => FlowBuilder<int>(
            state: value,
            onGeneratePages: (s, _) => [
              const MaterialPage<void>(child: _Root()),
              if (s > 0)
                const MaterialPage<void>(
                  child: Scaffold(body: Text('detail')),
                ),
            ],
          ),
        ),
      );
      expect(find.text('detail'), findsOneWidget);

      state.value = 0;
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
      expect(find.text('flow root'), findsOneWidget);

      await sendNavigation(tester, 'popRoute');
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('T-0037-AC4 outside any route the widget renders an empty '
        'box of its own', (tester) async {
      await tester.pumpWidget(const Align(child: McFlowBackButton()));

      expect(tester.takeException(), isNull);
      final own = find.descendant(
        of: find.byType(McFlowBackButton),
        matching: find.byType(SizedBox),
      );
      expect(own, findsOneWidget);
      expect(tester.getSize(own), Size.zero);
      expect(
        find.descendant(
          of: find.byType(McFlowBackButton),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });
  });
}
