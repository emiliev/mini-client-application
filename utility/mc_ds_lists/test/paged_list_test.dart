import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_paging/mc_paging.dart';

import 'shared_behaviour.dart';
import 'support.dart';

Widget _list(PagedHarness h, {required bool skeletons}) => McPagedList<int>(
  state: h.state,
  onLoadMore: h.onLoadMore,
  onRetry: h.onRetry,
  onRefresh: h.onRefresh,
  skeletonBuilder: skeletons
      ? (_) => Semantics(
          label: 'skeleton row',
          child: SizedBox(key: Key('skeleton'), height: 100),
        )
      : null,
  itemBuilder: (context, item, index) =>
      SizedBox(height: 100, child: Text('item $item')),
);

void main() {
  pagedBehaviour('McPagedList', _list);

  testWidgets('T-0031-AC1: McPagedList builds each item with its index', (
    tester,
  ) async {
    final seen = <int>[];
    await pumpOnSurface(
      tester,
      McPagedList<int>(
        state: pagedState(3, hasReachedEnd: true),
        onLoadMore: () {},
        onRetry: () {},
        onRefresh: () async {},
        itemBuilder: (context, item, index) {
          seen.add(index * 10 + item);
          return Text('row $item');
        },
      ),
    );
    expect(seen, [0, 11, 22]);
    expect(find.text('row 2'), findsOneWidget);
  });

  testWidgets('T-0031-AC2: McPagedList without a skeleton shows a spinner', (
    tester,
  ) async {
    await pumpOnSurface(
      tester,
      McPagedList<int>(
        state: const PagedState<int>(isLoadingMore: true),
        onLoadMore: () {},
        onRetry: () {},
        onRefresh: () async {},
        itemBuilder: (context, item, index) => Text('row $item'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
