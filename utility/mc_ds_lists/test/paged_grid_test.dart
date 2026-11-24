import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';

import 'shared_behaviour.dart';
import 'support.dart';

Widget _grid(PagedHarness h) => McPagedGrid<int>(
  state: h.state,
  onLoadMore: h.onLoadMore,
  onRetry: h.onRetry,
  onRefresh: h.onRefresh,
  cellHeight: (width, scaler) => 140,
  skeletonBuilder: (_) => const SizedBox(key: Key('skeleton'), height: 100),
  itemBuilder: (context, item, index) => Text('item $item'),
);

Future<int> _columns(WidgetTester tester, double width) async {
  await pumpOnSurface(
    tester,
    McPagedGrid<int>(
      state: pagedState(8, hasReachedEnd: true),
      onLoadMore: () {},
      onRetry: () {},
      onRefresh: () async {},
      padding: EdgeInsets.zero,
      cellHeight: (w, s) => 100,
      itemBuilder: (context, item, index) =>
          SizedBox(key: ValueKey(item), child: Text('item $item')),
    ),
    width: width,
    height: 800,
  );
  // Columns = items on the first row = items sharing the first item's top.
  final top = tester.getTopLeft(find.byKey(const ValueKey(0))).dy;
  return [
    for (var i = 0; i < 8; i++)
      if (tester.getTopLeft(find.byKey(ValueKey(i))).dy == top) i,
  ].length;
}

void main() {
  pagedBehaviour('McPagedGrid', _grid);

  testWidgets('T-0031-AC1: McPagedGrid has 2, 3 and 4 columns by width', (
    tester,
  ) async {
    expect(await _columns(tester, 375), 2);
    expect(await _columns(tester, 700), 3);
    expect(await _columns(tester, 1100), 4);
  });

  testWidgets('T-0031-AC4: the cell height follows the text scale callback', (
    tester,
  ) async {
    final seen = <double>[];
    await pumpOnSurface(
      tester,
      McPagedGrid<int>(
        state: pagedState(4, hasReachedEnd: true),
        onLoadMore: () {},
        onRetry: () {},
        onRefresh: () async {},
        cellHeight: (width, scaler) {
          seen.add(width);
          return 50 + scaler.scale(20);
        },
        itemBuilder: (context, item, index) =>
            SizedBox(key: ValueKey(item), child: Text('item $item')),
      ),
    );
    expect(seen, isNotEmpty);
    // 375 wide, 16 padding each side, 12 gap: (343 - 12) / 2.
    expect(seen.first, closeTo(165.5, 0.01));
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 70);
  });

  testWidgets('T-0031-AC1: the default cell is a 3:4 portrait', (
    tester,
  ) async {
    await pumpOnSurface(
      tester,
      McPagedGrid<int>(
        state: pagedState(4, hasReachedEnd: true),
        onLoadMore: () {},
        onRetry: () {},
        onRefresh: () async {},
        itemBuilder: (context, item, index) =>
            SizedBox(key: ValueKey(item), child: Text('item $item')),
      ),
    );
    final size = tester.getSize(find.byKey(const ValueKey(0)));
    expect(size.height / size.width, closeTo(4 / 3, 0.01));
  });
}
