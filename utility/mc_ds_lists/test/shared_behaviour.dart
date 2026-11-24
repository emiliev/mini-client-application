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
/// skeletons must carry `Key('skeleton')`.
void pagedBehaviour(String name, Widget Function(PagedHarness h) build) {
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
    testWidgets('T-0031-AC1: asks once past 80 % and not before', (
      tester,
    ) async {
      final counts = await pump(tester, pagedState(20));
      final max = maxScroll(tester);
      expect(max, greaterThan(900), reason: 'the list must really scroll');

      // Up to about half: nothing.
      await tester.drag(scrollable(), Offset(0, -max * 0.5));
      await tester.pump();
      expect(scrollPixels(tester), lessThan(max * 0.8));
      expect(counts.loadMore, 0);

      // Past 80 %: exactly one call.
      await tester.drag(scrollable(), Offset(0, -max * 0.45));
      await tester.pump();
      expect(scrollPixels(tester), greaterThanOrEqualTo(max * 0.8));
      expect(counts.loadMore, 1);

      // More scrolling before the state changes asks for nothing more.
      await tester.drag(scrollable(), const Offset(0, 80));
      await tester.drag(scrollable(), const Offset(0, -200));
      await tester.fling(scrollable(), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(counts.loadMore, 1);
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
      expect(find.text('Could not load more.'), findsOneWidget);
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
