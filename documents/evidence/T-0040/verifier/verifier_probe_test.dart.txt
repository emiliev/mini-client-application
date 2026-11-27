// T-0040 Verifier probe (temporary; not committed).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _long =
    'A very long page title that keeps going well past the width of any phone';
const _five = [
  McTab(label: 'Overview'),
  McTab(label: 'Comics'),
  McTab(label: 'Events'),
  McTab(label: 'Series'),
  McTab(label: 'Stories'),
];

Widget _app(Widget home, {double scale = 1, McThemeVariant v = McThemeVariant.light}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: McTheme.of(v).copyWith(platform: TargetPlatform.iOS),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: home,
    );

void main() {
  setUpAll(mcLoadFonts);

  for (final scale in [2.0, 3.0]) {
    for (final large in [false, true]) {
      testWidgets('PROBE geometry scale=$scale large=$large', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          mcSetSurface(tester, 375, 300);
          for (final t in ['Characters', _long]) {
            await tester.pumpWidget(_app(
              Scaffold(
                appBar: McAppBar(
                  title: t,
                  largeTitle: large,
                  titleKey: const Key('t'),
                  leading: const BackButton(),
                  actions: [McIconButton(icon: Icons.search, semanticLabel: 'Search', onPressed: () {})],
                ),
                body: const SizedBox.expand(),
              ),
              scale: scale,
            ));
            final bar = tester.getRect(find.byType(AppBar));
            final title = tester.getRect(find.byKey(const Key('t')));
            final rp = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const Key('t')), matching: find.byType(RichText)));
            final full = TextPainter(text: rp.text, textDirection: TextDirection.ltr, textScaler: rp.textScaler)..layout();
            // ignore_for_file: avoid_print
            print('PROBE scale=$scale large=$large title="${t.substring(0, 10)}" bar=$bar title=$title '
                'paragraphSize=${rp.size} intrinsicLineH=${full.height} effScale=${rp.textScaler.scale(10) / 10} '
                'didExceedMaxLines=${rp.didExceedMaxLines} exc=${tester.takeException()}');
          }
          await tester.pumpWidget(_app(
            Scaffold(
              appBar: McAppBar(
                title: _long,
                largeTitle: large,
                leading: const BackButton(),
                actions: [McIconButton(icon: Icons.search, semanticLabel: 'Search', onPressed: () {})],
              ),
              body: const Center(child: Text('body')),
            ),
            scale: scale,
          ));
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('verifier/probe_long_${large ? 'large' : 'plain'}_x${scale.toStringAsFixed(0)}.png'));
          await tester.pumpWidget(_app(
            Scaffold(
              appBar: McAppBar(
                title: 'Characters',
                largeTitle: large,
                leading: const BackButton(),
                actions: [McIconButton(icon: Icons.search, semanticLabel: 'Search', onPressed: () {})],
              ),
              body: const Center(child: Text('body')),
            ),
            scale: scale,
          ));
          await expectLater(find.byType(MaterialApp),
              matchesGoldenFile('verifier/probe_short_${large ? 'large' : 'plain'}_x${scale.toStringAsFixed(0)}.png'));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  testWidgets('PROBE semantics tree of plain and large bars', (tester) async {
    final handle = tester.ensureSemantics();
    for (final large in [false, true]) {
      await tester.pumpWidget(_app(Scaffold(
        appBar: McAppBar(title: 'Characters', largeTitle: large, leading: const BackButton()),
        body: McTabBar(tabs: _five.sublist(0, 2), currentIndex: 1, onChanged: (_) {}),
      )));
      final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      print('PROBE tree large=$large\n${root.toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder)}');
      final headers = <String>[];
      void visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isHeader) headers.add('${d.label}|namesRoute=${d.flagsCollection.namesRoute}');
        n.visitChildren((c) { visit(c); return true; });
      }
      visit(root);
      print('PROBE headers large=$large: $headers');
      expect(headers.where((h) => h.startsWith('Characters')), hasLength(1));
    }
    handle.dispose();
  });

  testWidgets('PROBE reveal on first build (fresh mount at index 4)', (tester) async {
    mcSetSurface(tester, 320, 400);
    await tester.pumpWidget(_app(Scaffold(
      body: McTabBar(tabs: _five, currentIndex: 4, onChanged: (_) {}),
    ), scale: 2));
    await tester.pumpAndSettle();
    final pos = tester.state<ScrollableState>(find.descendant(of: find.byType(McTabBar), matching: find.byType(Scrollable))).position;
    final r = tester.getRect(find.text('Stories'));
    print('PROBE first-build reveal pixels=${pos.pixels} max=${pos.maxScrollExtent} stories=$r');
    expect(pos.pixels, greaterThan(0));
    expect(r.right, lessThanOrEqualTo(320));
    expect(r.left, greaterThanOrEqualTo(0));
  });

  testWidgets('PROBE controlled index: tap does not select by itself; out of range', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <int>[];
    await tester.pumpWidget(_app(Scaffold(
      body: McTabBar(tabs: _five, currentIndex: 0, onChanged: taps.add),
    )));
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    final ev = tester.getSemantics(find.bySemanticsLabel('Events')).getSemanticsData();
    final ov = tester.getSemantics(find.bySemanticsLabel('Overview')).getSemanticsData();
    print('PROBE after tap without parent update: taps=$taps events.selected=${ev.flagsCollection.isSelected} overview.selected=${ov.flagsCollection.isSelected}');
    expect(ev.flagsCollection.isSelected, Tristate.isFalse);
    expect(ov.flagsCollection.isSelected, Tristate.isTrue);
    // Out of range index.
    await tester.pumpWidget(_app(Scaffold(
      body: McTabBar(tabs: _five, currentIndex: 7, onChanged: taps.add),
    )));
    print('PROBE currentIndex=7 exc=${tester.takeException()}');
    await tester.pumpWidget(_app(Scaffold(
      body: McTabBar(tabs: _five, currentIndex: -1, onChanged: taps.add),
    )));
    print('PROBE currentIndex=-1 exc=${tester.takeException()}');
    handle.dispose();
  });

  testWidgets('PROBE controlled index: parent update moves selection and reveal', (tester) async {
    mcSetSurface(tester, 320, 400);
    var index = 0;
    late StateSetter set;
    await tester.pumpWidget(_app(Scaffold(
      body: StatefulBuilder(builder: (c, s) {
        set = s;
        return McTabBar(tabs: _five, currentIndex: index, onChanged: (i) => s(() => index = i));
      }),
    ), scale: 2));
    await tester.pumpAndSettle();
    set(() => index = 4);
    await tester.pumpAndSettle();
    final pos = tester.state<ScrollableState>(find.descendant(of: find.byType(McTabBar), matching: find.byType(Scrollable))).position;
    print('PROBE parent update to 4: pixels=${pos.pixels} stories=${tester.getRect(find.text('Stories'))}');
    set(() => index = 0);
    await tester.pumpAndSettle();
    print('PROBE parent update back to 0: pixels=${pos.pixels} overview=${tester.getRect(find.text('Overview'))}');
    expect(pos.pixels, 0);
  });

  for (final v in McThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('PROBE guidelines large title + tabs ${v.name} x$scale', (tester) async {
        final handle = tester.ensureSemantics();
        mcSetSurface(tester, 375, 700);
        await tester.pumpWidget(_app(
          Scaffold(
            appBar: McAppBar(
              title: 'Characters',
              largeTitle: true,
              leading: const BackButton(),
              actions: [McIconButton(icon: Icons.search, semanticLabel: 'Search', onPressed: () {})],
            ),
            body: Column(children: [
              McTabBar(tabs: _five, currentIndex: 3, onChanged: (_) {}),
              McTabBar(tabs: _five.sublist(0, 2), currentIndex: 1, onChanged: (_) {}),
              McSectionHeader(title: 'Featured', actionLabel: 'See all', onAction: () {}),
            ]),
          ),
          scale: scale,
          v: v,
        ));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('PROBE tab bar height by parent', (tester) async {
    mcSetSurface(tester, 375, 600);
    Future<Size> sizeIn(Widget Function(Widget) wrap) async {
      await tester.pumpWidget(_app(Scaffold(body: wrap(
        McTabBar(tabs: _five.sublist(0, 2), currentIndex: 0, onChanged: (_) {}),
      ))));
      return tester.getSize(find.byType(McTabBar));
    }
    print('PROBE tabbar in Column: ${await sizeIn((c) => Column(children: [c]))}');
    print('PROBE tabbar in Align(topCenter): ${await sizeIn((c) => Align(alignment: Alignment.topCenter, child: c))}');
    print('PROBE tabbar in SizedBox(h:200)+Align: ${await sizeIn((c) => Align(alignment: Alignment.topCenter, child: SizedBox(height: 200, child: c)))}');
    print('PROBE tabbar in ListView: ${await sizeIn((c) => ListView(children: [c]))}');
    print('PROBE tabbar as body: ${await sizeIn((c) => c)}');
  });
}
