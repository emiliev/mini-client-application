import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';

Future<int> _columnsAt(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SingleChildScrollView(
        child: McAdaptiveGrid(
          children: [for (var i = 0; i < 8; i++) Text('tile $i')],
        ),
      ),
    ),
  );
  final grid = tester.widget<GridView>(find.byType(GridView));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

void main() {
  testWidgets('T-0019-AC3 grid shows 2 columns at width 375', (tester) async {
    expect(await _columnsAt(tester, 375), 2);
    // Two columns: tile 0 and tile 1 share a row, tile 2 starts the next.
    final y0 = tester.getTopLeft(find.text('tile 0')).dy;
    expect(tester.getTopLeft(find.text('tile 1')).dy, y0);
    expect(tester.getTopLeft(find.text('tile 2')).dy, greaterThan(y0));
  });

  testWidgets('T-0019-AC3 grid shows 4 columns at width 1024', (tester) async {
    expect(await _columnsAt(tester, 1024), 4);
    final y0 = tester.getTopLeft(find.text('tile 0')).dy;
    expect(tester.getTopLeft(find.text('tile 3')).dy, y0);
    expect(tester.getTopLeft(find.text('tile 4')).dy, greaterThan(y0));
  });

  test('T-0019-AC3 breakpoints: 599 compact, 600 medium, 1024 expanded', () {
    expect(McAdaptiveGrid.columnsFor(599), 2);
    expect(McAdaptiveGrid.columnsFor(600), 3);
    expect(McAdaptiveGrid.columnsFor(1023), 3);
    expect(McAdaptiveGrid.columnsFor(1024), 4);
  });

  testWidgets('T-0019-AC1 a11y: McA11y.duration is zero under reduced motion', (
    tester,
  ) async {
    late Duration d;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (c) {
            d = McA11y.duration(c, const Duration(milliseconds: 200));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(d, Duration.zero);
  });

  testWidgets('T-0019-AC3 grid in unbounded width falls back to the screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              McAdaptiveGrid(children: [Text('a')]),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final d = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(d.crossAxisCount, 4); // 1024-wide screen
  });
}
