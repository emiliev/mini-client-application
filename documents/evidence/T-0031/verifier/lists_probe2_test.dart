// Verifier probe round 2 (T-0031), kept as evidence. To re-run, copy into utility/mc_ds_lists/test with a flutter_test target (srcs = ["test/support.dart"], deps = _TEST_DEPS).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_cards/mc_ds_cards.dart';
import 'package:mc_ds_lists/mc_ds_lists.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

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
        print(
          'PROBE2 ${entry.key} skeleton=$skeleton maxWhileLoading=$maxLoading '
          'maxAfterPage=${maxScroll(t)} onLoadMore=$n',
        );
        expect(n, 1, reason: 'a short first page must ask for the next page');
      });
    }
  }

  testWidgets('PROBE2 default cellHeight with McMediaCard at scale 1', (
    t,
  ) async {
    await mcLoadFonts();
    final bundle = McFixtureAssetBundle();
    mcSetSurface(t, 375, 800);
    await t.pumpWidget(
      mcGoldenApp(
        bundle: bundle,
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
              itemBuilder: (c, i, _) => McMediaCard(
                image: ApiImage(path: 'mock-asset://characters/$i'),
                title: 'Wiimm the Wanderer',
                subtitle: 'Hero',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final e = t.takeException();
    final cell = t.getSize(find.byType(McMediaCard).first);
    final need = McMediaCard.heightFor(
      width: cell.width,
      textScaler: TextScaler.noScaling,
    );
    final card = t.getRect(find.byType(McMediaCard).first);
    final title = t.getRect(find.text('Wiimm the Wanderer').first);
    final sub = t.getRect(find.text('Hero').first);
    final flexes = t
        .renderObjectList<RenderFlex>(
          find.descendant(
            of: find.byType(McMediaCard).first,
            matching: find.byType(Column),
          ),
        )
        .map((r) => '${r.size}')
        .toList();
    print(
      'PROBE2 default cell=$cell heightFor=$need exception=$e '
      'card=$card title=$title subtitle=$sub columns=$flexes',
    );
    expect(e, isNull, reason: 'default cell overflows McMediaCard');
  });
}
