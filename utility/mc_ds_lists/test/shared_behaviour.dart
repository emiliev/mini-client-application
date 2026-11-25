import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';

import 'support.dart';

/// What a widget under test gets from the shared behaviour tests.
class PagedHarness {
  PagedHarness({
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
    required this.onRefresh,
  });

  final PagedState<int> state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
}

class _Counts {
  int loadMore = 0;
  int retry = 0;
  int refresh = 0;
}

/// The behaviour `McPagedList` and `McPagedGrid` share (AC1, AC2). [build]
/// makes the widget; its items must show the text `item <n>`, and its
/// skeletons (when `skeletons` is true) must be a `Semantics(label: 'skeleton row')` around a `Key('skeleton')` box.
void pagedBehaviour(
  String name,
  Widget Function(PagedHarness h, {required bool skeletons}) builder,
) {
  Widget build(PagedHarness h) => builder(h, skeletons: true);

  Future<_Counts> pump(WidgetTester tester, PagedState<int> state) async {
    final counts = _Counts();
    await pumpOnSurface(
      tester,
      build(
        PagedHarness(
          state: state,
          onLoadMore: () => counts.loadMore++,
          onRetry: () => counts.retry++,
          onRefresh: () async => counts.refresh++,
        ),
      ),
    );
    return counts;
  }

  Finder scrollable() => find.byType(Scrollable).first;

  group('T-0031-AC1 $name load more', () {
    testWidgets('T-0031-AC1: asks once past 80 % and not just below it', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(20));
      // The extent of a lazily built list is estimated and moves as items are
      // built, so every check reads the live value, as the widget does.
      double max() => maxScroll(tester);
      expect(max(), greaterThan(900), reason: 'the list must really scroll');
      final gesture = await tester.startGesture(
        tester.getCenter(scrollable()),
      );
      // Finger down, moving up in 6 px steps: the content scrolls down.
      Future<void> stepTo(double fraction) async {
        for (var i = 0; i < 600; i++) {
          if (scrollPixels(tester) >= max() * fraction) {
            return;
          }
          await gesture.moveBy(const Offset(0, -6));
          await tester.pump();
        }
        fail('never reached ${fraction * 100} %');
      }

      // Just below 80 %: no request.
      await stepTo(0.77);
      expect(
        scrollPixels(tester),
        inInclusiveRange(max() * 0.77, max() * 0.795),
      );
      expect(counts.loadMore, 0);

      // Just past 80 %: exactly one.
      await stepTo(0.81);
      expect(
        scrollPixels(tester),
        inInclusiveRange(max() * 0.81, max() * 0.83),
      );
      expect(counts.loadMore, 1);

      // Further scrolling before the state changes asks for nothing more.
      await stepTo(0.97);
      await gesture.up();
      await tester.fling(scrollable(), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(counts.loadMore, 1);
    });

    testWidgets('T-0031-AC1: a dropped request is asked again by scrolling', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(20));
      double max() => maxScroll(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(scrollable()),
      );
      Future<void> move(double dy, bool Function() until) async {
        for (var i = 0; i < 800 && !until(); i++) {
          await gesture.moveBy(Offset(0, dy));
          await tester.pump();
        }
        expect(until(), isTrue);
      }

      await move(-6, () => scrollPixels(tester) >= max() * 0.85);
      expect(counts.loadMore, 1);
      // The owner ignored it: back below the threshold, then past it again.
      await move(6, () => scrollPixels(tester) < max() * 0.7);
      expect(counts.loadMore, 1);
      await move(-6, () => scrollPixels(tester) >= max() * 0.85);
      expect(counts.loadMore, 2);
      await gesture.up();
    });

    testWidgets('T-0031-AC1: asks again after the state changed', (
      tester,
    ) async {
      var state = pagedState(20);
      final counts = _Counts();
      late StateSetter setState;
      await pumpOnSurface(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            setState = set;
            return build(
              PagedHarness(
                state: state,
                onLoadMore: () => counts.loadMore++,
                onRetry: () => counts.retry++,
                onRefresh: () async {},
              ),
            );
          },
        ),
      );
      await tester.fling(scrollable(), const Offset(0, -4000), 4000);
      await tester.pumpAndSettle();
      expect(counts.loadMore, 1);

      // The next page arrived: 40 items.
      setState(() => state = pagedState(40));
      await tester.pumpAndSettle();
      await tester.fling(scrollable(), const Offset(0, -9000), 6000);
      await tester.pumpAndSettle();
      expect(counts.loadMore, 2);
    });

    testWidgets('T-0031-AC1: never asks at the end', (tester) async {
      final counts = await pump(tester, pagedState(20, hasReachedEnd: true));
      await tester.fling(scrollable(), const Offset(0, -9000), 6000);
      await tester.pumpAndSettle();
      expect(scrollPixels(tester), maxScroll(tester));
      expect(counts.loadMore, 0);
    });

    testWidgets('T-0031-AC1: never asks while a load is in flight', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(20, isLoadingMore: true));
      await tester.fling(scrollable(), const Offset(0, -9000), 6000);
      // The footer spinner animates forever, so settle by hand.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(scrollPixels(tester), maxScroll(tester));
      expect(counts.loadMore, 0);
    });

    testWidgets('T-0031-AC1: never asks after a failure', (tester) async {
      final counts = await pump(
        tester,
        pagedState(20, failure: const ApiFailure.offline('offline')),
      );
      await tester.fling(scrollable(), const Offset(0, -9000), 6000);
      await tester.pumpAndSettle();
      expect(scrollPixels(tester), maxScroll(tester));
      expect(counts.loadMore, 0);
    });

    testWidgets('T-0031-AC1: a list shorter than the viewport asks once', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(2));
      await tester.pump();
      expect(maxScroll(tester), 0);
      expect(counts.loadMore, 1);
      await tester.pump();
      expect(counts.loadMore, 1);
    });

    testWidgets('T-0031-AC1: pull to refresh calls onRefresh once', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(20, hasReachedEnd: true));
      await tester.drag(scrollable(), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(counts.refresh, 1);
    });
  });

  group('T-0031-AC1 $name short pages', () {
    for (final skeletons in [true, false]) {
      final suffix = skeletons ? 'with skeletons' : 'without skeletons';

      testWidgets(
        'T-0031-AC1: a short first page asks for the next one ($suffix)',
        (tester) async {
          var state = const PagedState<int>(isLoadingMore: true);
          final counts = _Counts();
          late StateSetter setState;
          await pumpOnSurface(
            tester,
            StatefulBuilder(
              builder: (context, set) {
                setState = set;
                return builder(
                  PagedHarness(
                    state: state,
                    onLoadMore: () => counts.loadMore++,
                    onRetry: () {},
                    onRefresh: () async {},
                  ),
                  skeletons: skeletons,
                );
              },
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(counts.loadMore, 0);

          // The real first-load sequence: loading, then a page that does not
          // fill the viewport.
          setState(() => state = pagedState(2));
          await tester.pump();
          await tester.pump();
          expect(maxScroll(tester), 0);
          expect(counts.loadMore, 1);
          await tester.pump();
          expect(counts.loadMore, 1);
        },
      );

      testWidgets(
        'T-0031-AC1: a list still short after page 2 asks for page 3 ($suffix)',
        (tester) async {
          var state = const PagedState<int>(isLoadingMore: true);
          final counts = _Counts();
          late StateSetter setState;
          await pumpOnSurface(
            tester,
            StatefulBuilder(
              builder: (context, set) {
                setState = set;
                return builder(
                  PagedHarness(
                    state: state,
                    onLoadMore: () => counts.loadMore++,
                    onRetry: () {},
                    onRefresh: () async {},
                  ),
                  skeletons: skeletons,
                );
              },
            ),
          );
          for (final (n, asked) in [(2, 1), (3, 2), (4, 3)]) {
            // Loading, then the next short page. No drag in between.
            setState(() => state = pagedState(n - 1, isLoadingMore: true));
            await tester.pump();
            setState(() => state = pagedState(n));
            await tester.pump();
            await tester.pump();
            expect(counts.loadMore, asked, reason: 'after $n items');
          }
        },
      );
    }
  });

  group('T-0031-AC2 $name states', () {
    testWidgets('T-0031-AC2: a failure keeps the items and offers Retry once', (
      tester,
    ) async {
      final counts = await pump(
        tester,
        pagedState(3, failure: const ApiFailure.offline('offline')),
      );
      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 2'), findsOneWidget);
      expect(find.text('Could not load.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(counts.retry, 1);
      expect(counts.loadMore, 0);
    });

    testWidgets('T-0031-AC2: loading more shows a row under the items', (
      tester,
    ) async {
      await pump(tester, pagedState(3, isLoadingMore: true));
      expect(find.text('item 0'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('T-0031-AC2: an empty settled state shows the empty view', (
      tester,
    ) async {
      await pump(tester, const PagedState<int>(hasReachedEnd: true));
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byKey(const Key('skeleton')), findsNothing);
    });

    testWidgets('T-0031-AC2: the first load shows the skeletons', (
      tester,
    ) async {
      await pump(tester, const PagedState<int>(isLoadingMore: true));
      expect(find.byKey(const Key('skeleton')), findsWidgets);
      expect(find.text('Nothing here yet'), findsNothing);
    });

    testWidgets('T-0031-AC2: a state before the first load shows skeletons', (
      tester,
    ) async {
      final counts = await pump(tester, const PagedState<int>());
      expect(find.byKey(const Key('skeleton')), findsWidgets);
      expect(counts.loadMore, 0);
    });

    testWidgets('T-0031-AC2: the skeleton announces one Loading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const PagedState<int>(isLoadingMore: true));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.bySemanticsLabel('skeleton row'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0031-AC2: a first-load failure shows the error view', (
      tester,
    ) async {
      final counts = await pump(
        tester,
        const PagedState<int>(failure: ApiFailure.offline('No network')),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('No network'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(counts.retry, 1);
    });
  });
}
