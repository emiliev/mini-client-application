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
}
