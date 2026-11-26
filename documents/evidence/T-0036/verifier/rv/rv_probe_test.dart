// T-0036 Verifier re-verification probes at cbadeb0 (kit level). Not part of
// the branch: copied into utility/mc_feature_flow/test/verifier_probe_test.dart
// with a temporary BUILD target, run, removed.
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

class _S {
  const _S([this.selected]);
  final String? selected;
}

final _rebuild = ValueNotifier<int>(0);

/// Const root page that rebuilds on [_rebuild] (a locale change stand-in).
class _Root extends StatelessWidget {
  const _Root({this.drawer = false});
  final bool drawer;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _rebuild,
    builder: (context, n, _) => Scaffold(
      drawer: drawer ? const Drawer() : null,
      appBar: AppBar(
        leading: const McFlowBackButton(),
        title: Text('root $n'),
      ),
      body: TextButton(
        onPressed: () => context
            .di<FeatureFlowController<_S>>()
            .update((_) => const _S('x')),
        child: const Text('select'),
      ),
    ),
  );
}

FeatureFlowController<_S> _ctl(WidgetTester tester) => tester
    .element(find.byType(_Root, skipOffstage: false).first)
    .di<FeatureFlowController<_S>>();

List<McFlowPage> _pages(_S s) => [
  const McFlowPage(name: 'list', child: _Root()),
  if (s.selected != null)
    McFlowPage(
      name: 'detail',
      child: Scaffold(
        appBar: AppBar(
          leading: const McFlowBackButton(),
          title: const Text('detail'),
        ),
      ),
    ),
];

Widget _host(Widget Function() flow) => MaterialApp(
  theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => flow()),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

Widget _flow() => FeatureFlow<_S>(state: const _S(), onGeneratePages: _pages);

int _back() => find.byType(BackButton).evaluate().length;
bool _home() => find.text('open').evaluate().isNotEmpty;

Future<void> _swipe(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.dragFrom(Offset(2, size.height / 2), Offset(size.width * 0.8, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('R1 inner page with the widget: one back button, pops only it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    final n = _back();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    print('R1 inner back buttons=$n; after tap detail='
        '${find.text('detail').evaluate().isNotEmpty} home=${_home()} '
        'root back buttons=${_back()}');
    expect(n, 1);
    expect(find.text('detail'), findsNothing);
    expect(_home(), isFalse);
    expect(_back(), 1);
  });

  testWidgets('R2 dead-button repro: return by controller.update, then tap', (
    tester,
  ) async {
    _rebuild.value = 0;
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S('x'));
    await tester.pumpAndSettle();
    _rebuild.value++;
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S());
    await tester.pumpAndSettle();
    final scopes = tester
        .widgetList(
          find.byWidgetPredicate((w) => w is PopScope, skipOffstage: false),
        )
        .map((w) => (w as PopScope).canPop)
        .toList();
    var taps = 0;
    while (!_home() && taps < 6) {
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      taps++;
    }
    print('R2 PopScope canPop values=$scopes; taps to leave=$taps home=${_home()}');
    expect(taps, 1);
    expect(_home(), isTrue);
  });

  testWidgets('R3 dead-button repro, the iOS edge swipe', (tester) async {
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S('x'));
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S());
    await tester.pumpAndSettle();
    await _swipe(tester);
    print('R3 home after one edge swipe=${_home()}');
    expect(_home(), isTrue);
  });

  for (final frames in [0, 1, 2]) {
    testWidgets('R4 rapid: x then root in one frame, tap after $frames '
        'frame(s)', (tester) async {
      await tester.pumpWidget(_host(_flow));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      _ctl(tester)
        ..update((_) => const _S('x'))
        ..update((_) => const _S());
      for (var i = 0; i < frames; i++) {
        await tester.pump();
      }
      final n = _back();
      if (n == 1) {
        await tester.tap(find.byType(BackButton), warnIfMissed: false);
      }
      await tester.pumpAndSettle();
      final first = _home();
      var extra = 0;
      while (!_home() && extra < 3 && _back() == 1) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        extra++;
      }
      print('R4 frames=$frames back buttons=$n home after first tap=$first '
          'extra taps=$extra home=${_home()} '
          'exception=${tester.takeException()}');
    });
  }

  testWidgets('R4b update to x then immediately tap the root back (pop '
      'before the push lands)', (tester) async {
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S('x'));
    await tester.tap(find.byType(BackButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    print('R4b home=${_home()} detail=${find.text('detail').evaluate().isNotEmpty} '
        'exception=${tester.takeException()}');
  });

  testWidgets('R5 dispose while the post-frame callback is pending', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    _ctl(tester).update((_) => const _S('x'));
    // Same frame: the flow leaves the tree before its post-frame setState.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump();
    final e = tester.takeException();
    print('R5 exception after dispose with a pending post-frame=$e');
    expect(e, isNull);
  });

  testWidgets('R6 nested flows: inner flow root pops the outer flow page; '
      'after an inner state-driven return, one tap', (tester) async {
    late FeatureFlowController<_S> inner;
    late FeatureFlowController<_S> outer;
    await tester.pumpWidget(
      _host(
        () => FeatureFlow<_S>(
          state: const _S(),
          onGeneratePages: (s) => [
            McFlowPage(
              name: 'olist',
              child: Builder(
                builder: (context) {
                  outer = context.di<FeatureFlowController<_S>>();
                  return Scaffold(
                    appBar: AppBar(
                      leading: const McFlowBackButton(),
                      title: const Text('outer root'),
                    ),
                  );
                },
              ),
            ),
            if (s.selected != null)
              McFlowPage(
                name: 'nested',
                child: FeatureFlow<_S>(
                  state: const _S(),
                  onGeneratePages: (t) => [
                    McFlowPage(
                      name: 'ilist',
                      child: Builder(
                        builder: (context) {
                          inner = context.di<FeatureFlowController<_S>>();
                          return Scaffold(
                            appBar: AppBar(
                              leading: const McFlowBackButton(),
                              title: const Text('inner root'),
                            ),
                          );
                        },
                      ),
                    ),
                    if (t.selected != null)
                      McFlowPage(
                        name: 'idetail',
                        child: Scaffold(
                          appBar: AppBar(
                            leading: const McFlowBackButton(),
                            title: const Text('inner detail'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    outer.update((_) => const _S('n'));
    await tester.pumpAndSettle();
    expect(find.text('inner root'), findsOneWidget);
    final onInnerRoot = _back();
    inner.update((_) => const _S('d'));
    await tester.pumpAndSettle();
    final onInnerDetail = _back();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final afterInnerPop = find.text('inner root').evaluate().isNotEmpty;
    inner.update((_) => const _S('d'));
    await tester.pumpAndSettle();
    inner.update((_) => const _S());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final outerRootShown = find.text('outer root').evaluate().isNotEmpty;
    final outerState = outer.state.selected;
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    print('R6 back buttons inner root=$onInnerRoot inner detail=$onInnerDetail; '
        'inner pop kept inner root=$afterInnerPop; after inner state return '
        'one tap shows outer root=$outerRootShown (outer.selected=$outerState); '
        'next tap home=${_home()}');
    expect(onInnerRoot, 1);
    expect(onInnerDetail, 1);
    expect(afterInnerPop, isTrue);
    expect(outerRootShown, isTrue);
    expect(outerState, isNull);
    expect(_home(), isTrue);
  });

  testWidgets('R7 drawers: flow root pushed / flow is app root / inner page', (
    tester,
  ) async {
    // a) root with a drawer, flow pushed from home.
    await tester.pumpWidget(
      _host(
        () => FeatureFlow<_S>(
          state: const _S(),
          onGeneratePages: (s) => [
            const McFlowPage(name: 'list', child: _Root(drawer: true)),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final a = 'back=${_back()} drawer='
        '${find.byType(DrawerButton).evaluate().length}';
    // b) the flow is the app root, root page has a drawer (a fresh tree).
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
        home: FeatureFlow<_S>(
          state: const _S(),
          onGeneratePages: (s) => [
            const McFlowPage(name: 'list', child: _Root(drawer: true)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final b = 'back=${_back()} drawer='
        '${find.byType(DrawerButton).evaluate().length}';
    print('R7 root+drawer pushed: $a; root+drawer as app root: $b');
    expect(find.byType(DrawerButton), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('R8 fullscreen dialog pushed on the flow navigator', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_flow));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.text('select'));
    Navigator.of(ctx).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          appBar: AppBar(
            leading: const McFlowBackButton(),
            title: const Text('dialog'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final close = find.byType(CloseButton).evaluate().length;
    final back = _back();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    print('R8 dialog close=$close back=$back; after close dialog='
        '${find.text('dialog').evaluate().isNotEmpty} root='
        '${find.byType(_Root).evaluate().isNotEmpty} home=${_home()}');
    expect(close, 1);
    expect(back, 0);
    expect(find.text('dialog'), findsNothing);
    expect(_home(), isFalse);
  });

  testWidgets('R9 outside any route, and on a route outside any flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: McFlowBackButton(),
      ),
    );
    final e1 = tester.takeException();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(leading: const McFlowBackButton())),
      ),
    );
    final e2 = tester.takeException();
    print('R9 no route: exception=$e1 back=${_back()}; app home outside a '
        'flow: exception=${e2.runtimeType}');
    expect(e1, isNull);
  });
}
