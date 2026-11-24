// Verifier probe (T-0031), kept as evidence. To re-run, copy into the package test/ dir with a flutter_test target (deps = _TEST_DEPS).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'support.dart';

typedef Build = Widget Function(
  PagedState<int> s,
  VoidCallback onLoadMore,
);

Widget _grid(PagedState<int> s, VoidCallback more) => McPagedGrid<int>(
  state: s,
  onLoadMore: more,
  onRetry: () {},
  onRefresh: () async {},
  cellHeight: (w, _) => 140,
  itemBuilder: (c, i, _) => Text('item $i'),
);

Widget _list(PagedState<int> s, VoidCallback more) => McPagedList<int>(
  state: s,
  onLoadMore: more,
  onRetry: () {},
  onRefresh: () async {},
  itemBuilder: (c, i, _) => SizedBox(height: 100, child: Text('item $i')),
);

Finder _scrollable() => find.byType(Scrollable).first;

void probes(String name, Build build) {
  testWidgets('PROBE $name boundary: first call lands at 80 %', (t) async {
    var n = 0;
    await pumpOnSurface(t, build(pagedState(20), () => n++));
    final max = maxScroll(t);
    double? firedAt;
    double before = 0;
    for (var i = 0; i < 400 && firedAt == null; i++) {
      before = scrollPixels(t) / maxScroll(t);
      await t.drag(_scrollable(), const Offset(0, -40));
      await t.pump();
      if (n > 0) {
        firedAt = scrollPixels(t) / maxScroll(t);
      }
    }
    print(
      'PROBE $name max=$max before=$before firedAt=$firedAt '
      'maxNow=${maxScroll(t)}',
    );
    expect(before, lessThan(0.8));
    expect(firedAt, greaterThanOrEqualTo(0.8));
    expect(n, 1);
  });

  testWidgets('PROBE $name short list: once, no loop, then once per state', (
    t,
  ) async {
    var n = 0;
    var s = pagedState(2);
    late StateSetter set;
    await pumpOnSurface(
      t,
      StatefulBuilder(
        builder: (c, st) {
          set = st;
          return build(s, () => n++);
        },
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(n, 1, reason: 'short list asks exactly once and does not loop');
    // Overscroll up and down on a short list: still once.
    await t.drag(_scrollable(), const Offset(0, -200));
    await t.pumpAndSettle();
    await t.drag(_scrollable(), const Offset(0, 50));
    await t.pumpAndSettle();
    expect(n, 1);
    // Owner starts the load: in flight, no call.
    set(() => s = pagedState(2, isLoadingMore: true));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(n, 1);
    // Page arrives, still short: a new state, so it should ask once more.
    set(() => s = pagedState(4));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    print(
      'PROBE $name short list after page 2 (still short): n=$n '
      'max=${maxScroll(t)}',
    );
    final stalled = n == 1;
    // A user drag up recovers it.
    await t.drag(_scrollable(), const Offset(0, -100));
    await t.pumpAndSettle();
    print('PROBE $name short list after a user drag: n=$n');
    expect(stalled, isFalse, reason: 'stalls: page 2 still short, no ask');
  });

  testWidgets('PROBE $name fast fling past the end asks once', (t) async {
    var n = 0;
    await pumpOnSurface(t, build(pagedState(20), () => n++));
    await t.fling(_scrollable(), const Offset(0, -20000), 20000);
    await t.pumpAndSettle();
    await t.fling(_scrollable(), const Offset(0, -20000), 20000);
    await t.pumpAndSettle();
    expect(scrollPixels(t), maxScroll(t));
    expect(n, 1);
  });

  testWidgets('PROBE $name equal-value rebuild keeps the latch; new state '
      'resets it', (t) async {
    var n = 0;
    var s = pagedState(20);
    late StateSetter set;
    await pumpOnSurface(
      t,
      StatefulBuilder(
        builder: (c, st) {
          set = st;
          return build(s, () => n++);
        },
      ),
    );
    await t.fling(_scrollable(), const Offset(0, -9000), 6000);
    await t.pumpAndSettle();
    expect(n, 1);
    // A new but equal PagedState instance: no reset.
    set(() => s = pagedState(20));
    await t.pumpAndSettle();
    await t.drag(_scrollable(), const Offset(0, 100));
    await t.drag(_scrollable(), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(n, 1, reason: 'equal state must not re-arm');
    // In flight, then the same items back without end (e.g. owner retry
    // succeeded with an empty delta): the state changed, so a new crossing
    // fires once.
    set(() => s = pagedState(20, isLoadingMore: true));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(n, 1);
    set(() => s = pagedState(40));
    await t.pumpAndSettle();
    // Still at the old offset, below 80 % of the new extent: no call yet.
    expect(scrollPixels(t), lessThan(maxScroll(t) * 0.8));
    expect(n, 1);
    await t.fling(_scrollable(), const Offset(0, -20000), 20000);
    await t.pumpAndSettle();
    expect(n, 2);
  });

  testWidgets('PROBE $name rotation / resize', (t) async {
    var n = 0;
    await pumpOnSurface(t, build(pagedState(20), () => n++));
    final max = maxScroll(t);
    // Scroll to ~70 %.
    await t.drag(_scrollable(), Offset(0, -max * 0.7), touchSlopY: 0);
    await t.pumpAndSettle();
    final before = scrollPixels(t) / max;
    expect(n, 0);
    // Rotate to landscape: 600 wide (grid gets 3 columns), 375 tall.
    await pumpOnSurface(
      t,
      build(pagedState(20), () => n++),
      width: 812,
      height: 375,
    );
    await t.pumpAndSettle();
    final after = scrollPixels(t) / maxScroll(t);
    print(
      'PROBE $name rotate: before=$before after=$after n=$n '
      'max=${maxScroll(t)}',
    );
    expect(t.takeException(), isNull);
    expect(n, after >= 0.8 ? 1 : 0);
    // Rotate back: at most one more only if a new crossing happened; the
    // latch holds for this state.
    await pumpOnSurface(t, build(pagedState(20), () => n++));
    await t.pumpAndSettle();
    print(
      'PROBE $name rotate back: n=$n ratio=${scrollPixels(t) / maxScroll(t)}',
    );
    expect(n, lessThanOrEqualTo(1));
    expect(t.takeException(), isNull);
  });
}

void main() {
  for (final v in McThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      for (final st in [
        pagedState(2, failure: const ApiFailure.offline('Offline')),
        const PagedState<int>(failure: ApiFailure.offline('No network')),
        const PagedState<int>(hasReachedEnd: true),
      ]) {
        testWidgets('A11Y grid ${v.name} x$scale ${st.items.length} '
            '${st.failure != null}', (t) async {
          await mcLoadFonts();
          final h = t.ensureSemantics();
          mcSetSurface(t, 375, 640);
          await t.pumpWidget(
            mcGoldenApp(
              variant: v,
              textScale: scale,
              child: SizedBox(width: 375, height: 640, child: _grid(st, () {})),
            ),
          );
          await t.pump();
          await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          h.dispose();
        });
      }
    }
  }
  probes('grid', _grid);
  probes('list', _list);
}
