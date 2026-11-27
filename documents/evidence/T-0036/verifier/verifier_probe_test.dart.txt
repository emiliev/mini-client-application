// T-0036 Verifier probes (kit level). Not part of the branch: copied into
// utility/mc_feature_flow/test/ with a temporary BUILD target, run, removed.
// The root page uses LEADING_EXPR, which the negative control swaps for the
// old `context.flowLeading()`.
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

class _S {
  const _S([this.selected, this.root = 'list']);
  final String? selected;
  final String root;
}

final _rebuild = ValueNotifier<int>(0);
int _builds = 0;
TargetPlatform _platform = TargetPlatform.iOS;

/// Const root page; rebuilds on [_rebuild] (stands in for a locale change).
class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _rebuild,
    builder: (context, n, _) {
      _builds++;
      return Scaffold(
      appBar: AppBar(leading: LEADING_EXPR, title: Text('root $n')),
      body: TextButton(
        onPressed: () => context
            .di<FeatureFlowController<_S>>()
            .update((_S s) => _S('x', s.root)),
        child: const Text('select'),
      ),
    );
    },
  );
}

Widget _host(List<McFlowPage> Function(_S) pages) => MaterialApp(
  theme: McTheme.light.copyWith(platform: _platform),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                FeatureFlow<_S>(state: const _S(), onGeneratePages: pages),
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

List<McFlowPage> _pages(_S s) => [
  const McFlowPage(name: 'list', child: _Root()),
  if (s.selected != null)
    McFlowPage(
      name: 'detail',
      child: Scaffold(appBar: AppBar(title: const Text('detail'))),
    ),
];

int _onstageBack() => find.byType(BackButton).evaluate().length;

void main() {
  testWidgets('V1 real user pop: root rebuilt under the inner page keeps its '
      'back button, and one tap leaves the flow', (tester) async {
    _rebuild.value = 0;
    await tester.pumpWidget(_host(_pages));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final before = _onstageBack();
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);
    final onInner = _onstageBack();
    _rebuild.value++;
    await tester.pumpAndSettle();
    expect(find.text('root 1', skipOffstage: false), findsOneWidget);
    // The user taps the inner page's own (automatic) back button.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    final after = _onstageBack();
    print('V1 back buttons: root before=$before inner page up=$onInner '
        'root after pop=$after');
    expect(before, 1);
    expect(onInner, 1, reason: 'V2: no duplicate while the inner page is up');
    expect(after, 1, reason: 'the root back button survived the rebuild');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget, reason: 'one tap left the flow');
  });

  testWidgets('V1b same, with the iOS edge swipe instead of a tap', (
    tester,
  ) async {
    _rebuild.value = 0;
    await tester.pumpWidget(_host(_pages));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    _rebuild.value++;
    await tester.pumpAndSettle();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(
      Offset(2, size.height / 2),
      Offset(size.width * 0.8, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    final after = _onstageBack();
    print('V1b root back buttons after swipe=$after');
    expect(after, 1);
  });

  testWidgets('V3 (observation) McFlowBackButton misused on an inner page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (s) => [
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
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    print('V3 onstage back buttons on a misused inner page=${_onstageBack()}');
  });

  testWidgets('V4 a replaced root page (new first route) gets the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        (s) => [
          if (s.root == 'list')
            const McFlowPage(name: 'list', child: _Root())
          else
            McFlowPage(
              name: 'other',
              child: Scaffold(
                appBar: AppBar(
                  leading: const McFlowBackButton(),
                  title: const Text('other root'),
                ),
              ),
            ),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester
        .element(find.byType(_Root))
        .di<FeatureFlowController<_S>>()
        .update((_) => const _S(null, 'other'));
    await tester.pumpAndSettle();
    expect(find.text('other root'), findsOneWidget);
    final n = _onstageBack();
    print('V4 back buttons on the replacement root=$n');
    expect(n, 1);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('V5 ${platform.name}: tap the inner back; root build count', (
      tester,
    ) async {
      _platform = platform;
      addTearDown(() => _platform = TargetPlatform.iOS);
      _rebuild.value = 0;
      await tester.pumpWidget(_host(_pages));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('select'));
      await tester.pumpAndSettle();
      _rebuild.value++;
      await tester.pumpAndSettle();
      final b0 = _builds;
      final dirty = <String>[];
      debugOnRebuildDirtyWidget = (e, builtOnce) =>
          dirty.add(e.widget.runtimeType.toString().split('<').first);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      debugOnRebuildDirtyWidget = null;
      print('V5 ${platform.name} dirty-rebuilt widgets during the pop: '
          '${dirty.toSet().join(', ')}');
      final after = _onstageBack();
      print('V5 ${platform.name} root builds during the user pop='
          '${_builds - b0} back buttons after=$after');
      expect(after, 1);
    });

    testWidgets('V6 ${platform.name}: back to the root by controller.update '
        '(the AC1 test shape)', (tester) async {
      _platform = platform;
      addTearDown(() => _platform = TargetPlatform.iOS);
      _rebuild.value = 0;
      await tester.pumpWidget(_host(_pages));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('select'));
      await tester.pumpAndSettle();
      _rebuild.value++;
      await tester.pumpAndSettle();
      final b0 = _builds;
      tester
          .element(find.byType(_Root, skipOffstage: false))
          .di<FeatureFlowController<_S>>()
          .update((_) => const _S());
      await tester.pumpAndSettle();
      final after = _onstageBack();
      print('V6 ${platform.name} root builds during the update='
          '${_builds - b0} back buttons after=$after');
      expect(after, 1);
    });
  }

  testWidgets('V7 after a programmatic return to the root, taps needed on the '
      'root back button to leave the flow', (tester) async {
    _rebuild.value = 0;
    await tester.pumpWidget(_host(_pages));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    tester
        .element(find.byType(_Root, skipOffstage: false))
        .di<FeatureFlowController<_S>>()
        .update((_) => const _S());
    await tester.pumpAndSettle();
    final scopes = tester
        .widgetList(
          find.byWidgetPredicate((w) => w is PopScope, skipOffstage: false),
        )
        .map((w) => (w as PopScope).canPop)
        .toList();
    print('V7 PopScope canPop values after the programmatic return: $scopes');
    var taps = 0;
    while (find.text('open').evaluate().isEmpty && taps < 6) {
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      taps++;
      final st = tester
          .element(find.byType(_Root, skipOffstage: false))
          .di<FeatureFlowController<_S>>()
          .state;
      print('V7 after tap $taps: detail shown='
          '${find.text('detail').evaluate().isNotEmpty} '
          'root shown=${find.text('root 0').evaluate().isNotEmpty} '
          'home shown=${find.text('open').evaluate().isNotEmpty} '
          'state.selected=${st.selected}');
    }
    print('V7 taps to leave the flow after controller.update: $taps');
  });
}
