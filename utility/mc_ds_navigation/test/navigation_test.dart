import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
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

Widget _page({
  McAppBar? appBar,
  Widget? body,
  McThemeVariant variant = McThemeVariant.light,
  double scale = 1,
}) => MaterialApp(
  theme: McTheme.of(variant).copyWith(platform: TargetPlatform.iOS),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(appBar: appBar, body: body),
);

Widget _search() =>
    McIconButton(icon: Icons.search, semanticLabel: 'Search', onPressed: () {});

SemanticsData _data(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

void main() {
  setUpAll(mcLoadFonts);

  group('T-0040-AC1 no overflow', () {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('T-0040-AC1 long titles at ${scale}x do not overflow', (
        tester,
      ) async {
        mcSetSurface(tester, 375, 600);
        for (final large in [false, true]) {
          await tester.pumpWidget(
            _page(
              scale: scale,
              appBar: McAppBar(
                title: _long,
                largeTitle: large,
                leading: const BackButton(),
                actions: [_search()],
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    McTabBar(tabs: _five, currentIndex: 4, onChanged: (_) {}),
                    const McSectionHeader(title: _long),
                    McSectionHeader(
                      title: _long,
                      actionLabel: 'See all',
                      onAction: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: 'large=$large');
        }
      });
    }
  });

  testWidgets('T-0040-AC1 the large title stays inside its band at 3x', (
    tester,
  ) async {
    mcSetSurface(tester, 375, 600);
    await tester.pumpWidget(
      _page(
        scale: 3,
        appBar: const McAppBar(
          title: 'Characters',
          largeTitle: true,
          titleKey: Key('title'),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('title'))).height,
      lessThanOrEqualTo(McAppBar.largeTitleExtent),
    );
    // The text itself is drawn at the capped scale, not just clipped to the
    // band (the paragraph would otherwise be 3x tall and painted outside).
    final text = tester.widget<Text>(find.byKey(const Key('title')));
    expect(
      text.textScaler!.scale(10),
      lessThanOrEqualTo(10 * McAppBar.largeTitleMaxScale),
    );
  });

  testWidgets('T-0040-AC1 the large title adds a fixed band to the height', (
    tester,
  ) async {
    const plain = McAppBar(title: 'A');
    const large = McAppBar(title: 'A', largeTitle: true);
    expect(
      large.preferredSize.height - plain.preferredSize.height,
      McAppBar.largeTitleExtent,
    );
    mcSetSurface(tester, 375, 600);
    await tester.pumpWidget(_page(appBar: large));
    expect(
      tester.getSize(find.byType(AppBar)).height,
      large.preferredSize.height,
    );
  });

  group('T-0040-AC2 semantics', () {
    testWidgets('T-0040-AC2 the McAppBar title is a header', (tester) async {
      final handle = tester.ensureSemantics();
      for (final large in [false, true]) {
        await tester.pumpWidget(
          _page(
            appBar: McAppBar(
              title: 'Characters',
              largeTitle: large,
              titleKey: const Key('title'),
            ),
          ),
        );
        expect(find.byKey(const Key('title')), findsOneWidget);
        final data = _data(tester, find.byKey(const Key('title')));
        expect(data.label, 'Characters', reason: 'large=$large');
        expect(
          data.flagsCollection.isHeader,
          isTrue,
          reason: 'large=$large',
        );
      }
      handle.dispose();
    });

    testWidgets('T-0040-AC2 the McSectionHeader title is a header', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(body: const McSectionHeader(title: 'Featured')),
      );
      final data = _data(tester, find.text('Featured'));
      expect(data.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('T-0040-AC2 tabs are selectable tabs with their labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          body: McTabBar(tabs: _five, currentIndex: 1, onChanged: (_) {}),
        ),
      );
      for (var i = 0; i < _five.length; i++) {
        final data = _data(tester, find.bySemanticsLabel(_five[i].label));
        expect(data.label, _five[i].label);
        expect(data.role, SemanticsRole.tab, reason: _five[i].label);
        expect(
          data.flagsCollection.isSelected,
          i == 1 ? Tristate.isTrue : Tristate.isFalse,
          reason: _five[i].label,
        );
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
      final bar = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.tabBar,
      );
      expect(bar, findsOneWidget);
      var children = 0;
      tester.getSemantics(bar).visitChildren((_) => ++children > 0);
      expect(children, _five.length);
      handle.dispose();
    });

    testWidgets('T-0040-AC2 every tap target is at least 44 pt', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          appBar: McAppBar(
            title: 'Characters',
            leading: const BackButton(),
            actions: [_search()],
          ),
          body: Column(
            children: [
              McTabBar(tabs: _five, currentIndex: 0, onChanged: (_) {}),
              McSectionHeader(
                title: 'Featured',
                actionLabel: 'All',
                onAction: () {},
              ),
            ],
          ),
        ),
      );
      final targets = <Finder>[
        find.byType(BackButton),
        find.byType(McIconButton),
        find.byType(TextButton),
        find.descendant(
          of: find.byType(McTabBar),
          matching: find.byType(InkWell),
        ),
      ];
      var counted = 0;
      for (final f in targets) {
        expect(f, findsWidgets);
        for (final e in f.evaluate()) {
          final size = tester.getSize(find.byElementPredicate((x) => x == e));
          counted++;
          expect(size.width, greaterThanOrEqualTo(mcMinTapTarget));
          expect(size.height, greaterThanOrEqualTo(mcMinTapTarget));
        }
      }
      expect(counted, 8);
    });

    for (final variant in McThemeVariant.values) {
      testWidgets(
        'T-0040-AC2 meetsGuideline (tap target, label, contrast) ${variant.name}',
        (tester) async {
          final handle = tester.ensureSemantics();
          mcSetSurface(tester, 375, 600);
          await tester.pumpWidget(
            _page(
              variant: variant,
              appBar: McAppBar(
                title: 'Characters',
                leading: const BackButton(),
                actions: [_search()],
              ),
              body: Column(
                children: [
                  McTabBar(tabs: _five, currentIndex: 0, onChanged: (_) {}),
                  McSectionHeader(
                    title: 'Featured',
                    actionLabel: 'See all',
                    onAction: () {},
                  ),
                ],
              ),
            ),
          );
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        },
      );
    }
  });

  group('T-0040-AC3 leading slot', () {
    testWidgets('T-0040-AC3 the leading widget fills the slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          appBar: const McAppBar(
            title: 'Characters',
            leading: Text('LEAD', key: Key('lead')),
          ),
        ),
      );
      expect(find.byKey(const Key('lead')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const Key('lead')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('T-0040-AC3 a null leading gives the automatic back button', (
      tester,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: McTheme.light,
          home: const Scaffold(appBar: McAppBar(title: 'Home')),
        ),
      );
      expect(find.byType(BackButton), findsNothing);
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(appBar: McAppBar(title: 'Inner')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('T-0040-AC1 behaviour', () {
    testWidgets('T-0040-AC1 tapping a tab reports its index', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        _page(
          body: McTabBar(tabs: _five, currentIndex: 0, onChanged: taps.add),
        ),
      );
      await tester.tap(find.text('Events'));
      await tester.tap(find.text('Overview'));
      expect(taps, [2, 0]);
    });

    testWidgets('T-0040-AC1 five tabs scroll when they do not fit', (
      tester,
    ) async {
      mcSetSurface(tester, 320, 400);
      await tester.pumpWidget(
        _page(
          scale: 2,
          body: McTabBar(tabs: _five, currentIndex: 0, onChanged: (_) {}),
        ),
      );
      expect(tester.takeException(), isNull);
      final scroll = find.descendant(
        of: find.byType(McTabBar),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('T-0040-AC1 the selected tab is scrolled into view', (
      tester,
    ) async {
      mcSetSurface(tester, 320, 400);
      Future<double> offsetFor(int index) async {
        await tester.pumpWidget(
          _page(
            scale: 2,
            body: McTabBar(
              tabs: _five,
              currentIndex: index,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final scroll = find.descendant(
          of: find.byType(McTabBar),
          matching: find.byType(Scrollable),
        );
        return tester.state<ScrollableState>(scroll).position.pixels;
      }

      expect(await offsetFor(0), 0);
      expect(await offsetFor(4), greaterThan(0));
      final box = tester.getRect(find.text('Stories'));
      expect(box.right, lessThanOrEqualTo(320));
    });

    testWidgets('T-0040-AC1 two tabs share the width', (tester) async {
      mcSetSurface(tester, 375, 400);
      await tester.pumpWidget(
        _page(
          body: McTabBar(
            tabs: const [
              McTab(label: 'One'),
              McTab(label: 'Two'),
            ],
            currentIndex: 0,
            onChanged: (_) {},
          ),
        ),
      );
      final one = tester.getCenter(find.text('One')).dx;
      final two = tester.getCenter(find.text('Two')).dx;
      expect(one, lessThan(375 / 2));
      expect(two, greaterThan(375 / 2));
    });

    testWidgets('T-0040-AC1 the section action fires once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _page(
          body: McSectionHeader(
            title: 'Featured',
            actionLabel: 'See all',
            onAction: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('See all'));
      expect(taps, 1);
    });
  });

  group('T-0040-AC1 fix round', () {
    Size barSize(WidgetTester tester) => tester.getSize(
      find
          .descendant(
            of: find.byType(McTabBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    const tabs2 = [McTab(label: 'One'), McTab(label: 'Two')];
    const fullHeight = McTabBar.height + McTabBar.dividerHeight;

    testWidgets('T-0040-AC1 the tab bar is 49 pt high in a Column', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          body: Column(
            children: [
              McTabBar(tabs: tabs2, currentIndex: 0, onChanged: (_) {}),
            ],
          ),
        ),
      );
      expect(barSize(tester).height, fullHeight);
      expect(tester.getSize(find.byType(McTabBar)).height, fullHeight);
    });

    testWidgets('T-0040-AC1 the tab bar is 49 pt high in a tall box', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 700);
      await tester.pumpWidget(
        _page(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 600,
              child: Align(
                alignment: Alignment.topCenter,
                child: McTabBar(
                  tabs: tabs2,
                  currentIndex: 0,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(barSize(tester).height, fullHeight);
    });

    testWidgets('T-0040-AC1 the tab bar is 49 pt high as a page body', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          body: McTabBar(tabs: tabs2, currentIndex: 0, onChanged: (_) {}),
        ),
      );
      expect(barSize(tester).height, fullHeight);
      // The tab itself is 48 pt, not the body's height.
      expect(tester.getSize(find.byType(InkWell).first).height, 48);
    });

    testWidgets('T-0040-AC1 a tall text scale keeps the tabs 48 pt', (
      tester,
    ) async {
      mcSetSurface(tester, 375, 600);
      await tester.pumpWidget(
        _page(
          scale: 3,
          body: Column(
            children: [
              McTabBar(tabs: _five, currentIndex: 0, onChanged: (_) {}),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(InkWell).first).height, 48);
      final text = tester.widget<Text>(find.text('Overview'));
      expect(
        text.textScaler!.scale(10),
        lessThanOrEqualTo(10 * McTabBar.labelMaxScale),
      );
    });

    testWidgets(
      'T-0040-AC1 a tab bar inside a vertical ListView leaves the page offset',
      (tester) async {
        mcSetSurface(tester, 320, 400);
        final page = ScrollController();
        addTearDown(page.dispose);
        var index = 0;
        late StateSetter set;
        await tester.pumpWidget(
          _page(
            scale: 2,
            body: StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return ListView(
                  controller: page,
                  children: [
                    const SizedBox(height: 300),
                    McTabBar(
                      tabs: _five,
                      currentIndex: index,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 1200),
                  ],
                );
              },
            ),
          ),
        );
        expect(page.offset, 0, reason: 'build must not scroll the page');
        page.jumpTo(100);
        await tester.pumpAndSettle();
        set(() => index = 4);
        await tester.pumpAndSettle();
        expect(
          page.offset,
          100,
          reason: 'a tab change must not scroll the page',
        );
        // The bar's own row did scroll.
        final bar = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(McTabBar),
            matching: find.byType(Scrollable),
          ),
        );
        expect(bar.position.pixels, greaterThan(0));
      },
    );

    testWidgets(
      'T-0040-AC1 the first build in a ListView does not scroll the page',
      (tester) async {
        mcSetSurface(tester, 320, 400);
        final page = ScrollController(initialScrollOffset: 0);
        addTearDown(page.dispose);
        await tester.pumpWidget(
          _page(
            scale: 2,
            body: ListView(
              controller: page,
              children: [
                const SizedBox(height: 500),
                McTabBar(tabs: _five, currentIndex: 4, onChanged: (_) {}),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(page.offset, 0);
      },
    );

    testWidgets(
      'T-0040-AC1 a parent rebuild with the same index does not snap the bar',
      (tester) async {
        mcSetSurface(tester, 320, 400);
        late StateSetter set;
        await tester.pumpWidget(
          _page(
            scale: 2,
            body: StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return McTabBar(
                  tabs: _five,
                  currentIndex: 4,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bar = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(McTabBar),
            matching: find.byType(Scrollable),
          ),
        );
        expect(bar.position.pixels, bar.position.maxScrollExtent);
        bar.position.jumpTo(0);
        await tester.pump();
        set(() {});
        await tester.pumpAndSettle();
        expect(bar.position.pixels, 0, reason: 'same index: no reveal');
      },
    );

    testWidgets(
      'T-0040-AC1 fitting tabs fill the width, so gaps select a tab',
      (tester) async {
        mcSetSurface(tester, 375, 400);
        final taps = <int>[];
        await tester.pumpWidget(
          _page(
            body: Column(
              children: [
                McTabBar(
                  tabs: const [
                    McTab(label: 'A'),
                    McTab(label: 'A much longer tab'),
                    McTab(label: 'C'),
                  ],
                  currentIndex: 0,
                  onChanged: taps.add,
                ),
              ],
            ),
          ),
        );
        final rects = [
          for (final e in find.byType(InkWell).evaluate())
            tester.getRect(find.byElementPredicate((x) => x == e)),
        ];
        expect(rects, hasLength(3));
        expect(rects.first.left, 0);
        expect(rects.last.right, closeTo(375, 0.01));
        for (var i = 1; i < rects.length; i++) {
          expect(rects[i].left, closeTo(rects[i - 1].right, 0.01));
        }
        // The first tab is wider than its label, and a tap on its empty part
        // hits it.
        final label = tester.getRect(find.text('A'));
        expect(rects[0].width, greaterThan(label.width + 32));
        await tester.tapAt(Offset(rects[0].right - 2, rects[0].center.dy));
        expect(taps, [0]);
      },
    );

    testWidgets('T-0040-AC1 an unbounded width does not crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(
          body: Row(
            children: [
              McTabBar(tabs: tabs2, currentIndex: 1, onChanged: (_) {}),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Two'), findsOneWidget);
    });

    testWidgets('T-0040-AC1 the tab bar works without a Scaffold', (
      tester,
    ) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.light,
          home: Align(
            alignment: Alignment.topCenter,
            child: McTabBar(tabs: tabs2, currentIndex: 0, onChanged: taps.add),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Two'));
      expect(taps, [1]);
    });

    testWidgets('T-0040-AC1 currentIndex out of range is asserted', (
      tester,
    ) async {
      expect(
        () => McTabBar(tabs: tabs2, currentIndex: 2, onChanged: (_) {}),
        throwsAssertionError,
      );
      expect(
        () => McTabBar(tabs: tabs2, currentIndex: -1, onChanged: (_) {}),
        throwsAssertionError,
      );
    });

    testWidgets(
      'T-0040-AC1 the tab bar works as AppBar.bottom and McAppBar.bottom',
      (tester) async {
        mcSetSurface(tester, 375, 600);
        final bar = McTabBar(tabs: tabs2, currentIndex: 0, onChanged: (_) {});
        expect(bar.preferredSize.height, fullHeight);
        await tester.pumpWidget(
          _page(
            appBar: McAppBar(title: 'Series', bottom: bar),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AppBar)).height,
          kToolbarHeight + fullHeight,
        );
        expect(find.byType(McTabBar), findsOneWidget);
        // Large title plus tabs.
        await tester.pumpWidget(
          _page(
            appBar: McAppBar(title: 'Series', largeTitle: true, bottom: bar),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AppBar)).height,
          kToolbarHeight + McAppBar.largeTitleExtent + fullHeight,
        );
        // Plain AppBar.bottom.
        await tester.pumpWidget(
          MaterialApp(
            theme: McTheme.light,
            home: Scaffold(
              appBar: AppBar(title: const Text('x'), bottom: bar),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AppBar)).height,
          kToolbarHeight + fullHeight,
        );
      },
    );

    testWidgets(
      'T-0040-AC1 a long German action label at 3x does not overflow',
      (tester) async {
        mcSetSurface(tester, 320, 600);
        await tester.pumpWidget(
          _page(
            scale: 3,
            body: McSectionHeader(
              title: 'Ausgewählte Figuren',
              actionLabel: 'Alle Donaudampfschifffahrtsgesellschaft anzeigen',
              onAction: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(TextButton)).width,
          lessThanOrEqualTo(320),
        );
      },
    );

    testWidgets('T-0040-AC1 the high-contrast divider has no alpha', (
      tester,
    ) async {
      Color divider() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(McTabBar),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return ((box.decoration as BoxDecoration).border! as Border)
            .bottom
            .color;
      }

      await tester.pumpWidget(
        _page(
          body: McTabBar(tabs: tabs2, currentIndex: 0, onChanged: (_) {}),
        ),
      );
      expect(divider().a, lessThan(1));
      await tester.pumpWidget(
        MaterialApp(
          theme: McTheme.of(McThemeVariant.highContrast),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: app!,
          ),
          home: Scaffold(
            body: McTabBar(tabs: tabs2, currentIndex: 0, onChanged: (_) {}),
          ),
        ),
      );
      expect(divider().a, 1);
    });
  });

  group('T-0040-AC2 fix round', () {
    testWidgets('T-0040-AC2 a tab keeps its button flag', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          body: McTabBar(tabs: _five, currentIndex: 0, onChanged: (_) {}),
        ),
      );
      final data = _data(tester, find.bySemanticsLabel('Comics'));
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('T-0040-AC2 the large title names the route', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _page(
          appBar: const McAppBar(
            title: 'Characters',
            largeTitle: true,
            titleKey: Key('title'),
          ),
        ),
      );
      final data = _data(tester, find.byKey(const Key('title')));
      expect(data.flagsCollection.namesRoute, isTrue);
      expect(data.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });
  });
}
