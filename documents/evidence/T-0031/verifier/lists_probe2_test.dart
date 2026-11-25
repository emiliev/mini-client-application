// Verifier probe round 2 (T-0031), kept as evidence. To re-run, copy into utility/mc_ds_lists/test with a flutter_test target (srcs = ["test/support.dart"], deps = _TEST_DEPS).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_paging/mc_paging.dart';

import 'support.dart';

Widget _grid(PagedState<int> s, VoidCallback more, {bool skeleton = false}) =>
    McPagedGrid<int>(
      state: s,
      onLoadMore: more,
      onRetry: () {},
      onRefresh: () async {},
      cellHeight: (w, _) => 140,
      skeletonBuilder: skeleton
          ? (_) => const SizedBox(key: Key('skeleton'), height: 100)
          : null,
      itemBuilder: (c, i, _) => Text('item $i'),
    );

Widget _list(PagedState<int> s, VoidCallback more, {bool skeleton = false}) =>
    McPagedList<int>(
      state: s,
      onLoadMore: more,
      onRetry: () {},
      onRefresh: () async {},
      skeletonBuilder: skeleton
          ? (_) => const SizedBox(key: Key('skeleton'), height: 100)
          : null,
      itemBuilder: (c, i, _) => SizedBox(height: 100, child: Text('item $i')),
    );

void main() {
  for (final entry in {'grid': _grid, 'list': _list}.entries) {
    for (final skeleton in [false, true]) {
      testWidgets('PROBE2 ${entry.key} first load (skeleton=$skeleton) then a '
          'short page', (t) async {
        var n = 0;
        var s = const PagedState<int>(isLoadingMore: true);
        late StateSetter set;
        await pumpOnSurface(
          t,
          StatefulBuilder(
            builder: (c, st) {
              set = st;
              return entry.value(s, () => n++, skeleton: skeleton);
            },
          ),
        );
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        final maxLoading = maxScroll(t);
        expect(n, 0);
        set(() => s = pagedState(2));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        debugPrint(
          'PROBE2 ${entry.key} skeleton=$skeleton maxWhileLoading=$maxLoading '
          'maxAfterPage=${maxScroll(t)} onLoadMore=$n',
        );
        expect(n, 1, reason: 'a short first page must ask for the next page');
      });
    }
  }

  testWidgets('PROBE3 short list: a pull-down re-fires onLoadMore', (t) async {
    var n = 0;
    var refreshes = 0;
    await pumpOnSurface(
      t,
      McPagedList<int>(
        state: pagedState(2),
        onLoadMore: () => n++,
        onRetry: () {},
        onRefresh: () async => refreshes++,
        itemBuilder: (c, i, _) => SizedBox(height: 100, child: Text('item $i')),
      ),
    );
    await t.pump();
    final afterMount = n;
    await t.drag(find.byType(Scrollable).first, const Offset(0, 40));
    await t.pumpAndSettle();
    final afterSmallPull = n;
    await t.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await t.pumpAndSettle();
    debugPrint(
      'PROBE3 afterMount=$afterMount afterSmallPull=$afterSmallPull '
      'afterPullToRefresh=$n refreshes=$refreshes',
    );
  });

  testWidgets('PROBE3 semantics tree of a first-load grid of card skeletons', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await pumpOnSurface(
      t,
      McPagedGrid<int>(
        state: const PagedState<int>(isLoadingMore: true),
        onLoadMore: () {},
        onRetry: () {},
        onRefresh: () async {},
        cellHeight: (w, s) => McMediaCard.heightFor(width: w, textScaler: s),
        skeletonBuilder: (_) => const McMediaCard.skeleton(),
        itemBuilder: (c, i, _) => Text('item $i'),
      ),
    );
    await t.pump();
    final root =
        t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
    final labels = <String>[];
    void walk(SemanticsNode node) {
      final d = node.getSemanticsData();
      if (d.label.isNotEmpty) {
        labels.add(d.label);
      }
      node.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root);
    debugPrint('PROBE3 labelled nodes: $labels');
    expect(labels.where((l) => l.startsWith('Loading')), hasLength(1));
    h.dispose();
  });
}
