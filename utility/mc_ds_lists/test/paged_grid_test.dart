import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'shared_behaviour.dart';
import 'support.dart';

Widget _grid(PagedHarness h, {required bool skeletons}) => McPagedGrid<int>(
  state: h.state,
  onLoadMore: h.onLoadMore,
  onRetry: h.onRetry,
  onRefresh: h.onRefresh,
  cellHeight: (width, scaler) => 140,
  skeletonBuilder: skeletons
      ? (_) => Semantics(
          label: 'skeleton row',
          child: SizedBox(key: Key('skeleton'), height: 100),
        )
      : null,
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

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'T-0031-AC4: a card title is not clipped in its cell at scale $scale',
      (tester) async {
        mcSetSurface(tester, 375, 800);
        await tester.pumpWidget(
          mcGoldenApp(
            textScale: scale,
            bundle: McFixtureAssetBundle(),
            child: McMediaScope(
              resolver: const BundledImageResolver(),
              child: SizedBox(
                width: 375,
                height: 800,
                child: McPagedGrid<int>(
                  state: pagedState(4, hasReachedEnd: true),
                  onLoadMore: () {},
                  onRetry: () {},
                  onRefresh: () async {},
                  cellHeight: (width, scaler) =>
                      McMediaCard.heightFor(width: width, textScaler: scaler),
                  itemBuilder: (context, item, index) => McMediaCard(
                    image: ApiImage(path: 'mock-asset://characters/$item'),
                    title: 'Title $item',
                    subtitle: 'Hero',
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          final card = find.byType(McMediaCard).at(i);
          final cell = tester.getRect(card);
          for (final text in ['Title $i', 'Hero']) {
            final rect = tester.getRect(
              find.descendant(of: card, matching: find.text(text)),
            );
            expect(rect.height, greaterThan(0), reason: '$text at $scale');
            expect(
              cell.inflate(0.5).contains(rect.topLeft) &&
                  cell.inflate(0.5).contains(rect.bottomRight),
              isTrue,
              reason: '$text $rect outside cell $cell at scale $scale',
            );
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
