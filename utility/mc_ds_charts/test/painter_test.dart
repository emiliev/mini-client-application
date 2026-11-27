// T-0059-AC2: the painters, asserted through a recording canvas (the drawn
// rects, lines, arcs, circles and paths), not through pixels.
import 'dart:math' as math;
import 'dart:ui' show Paragraph;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

import 'support/recording_canvas.dart';

int _argb(Color c) => c.toARGB32();
List<int> _argbs(Iterable<Color> c) => [for (final x in c) x.toARGB32()];

const _style = TextStyle(fontSize: 12);
final _p = McPalette.light;
const _size = Size(300, 200);

McBarPainter _bar(
  List<McBarDatum> data, {
  bool vertical = true,
  int? highlight,
  double progress = 1,
  TextScaler scaler = TextScaler.noScaling,
}) => McBarPainter(
  data: data,
  palette: _p,
  labelStyle: _style,
  textScaler: scaler,
  vertical: vertical,
  valueFormatter: mcFormatValue,
  highlightIndex: highlight,
  progress: progress == 1
      ? kAlwaysCompleteAnimation
      : AlwaysStoppedAnimation(progress),
);

List<McBarDatum> _bars(List<double> v, {List<McChartRole?>? roles}) => [
  for (var i = 0; i < v.length; i++)
    McBarDatum(label: 'L$i', value: v[i], role: roles?[i]),
];

RecordingCanvas _paint(CustomPainter p, [Size size = _size]) {
  final c = RecordingCanvas();
  p.paint(c, size);
  return c;
}

bool _finite(Offset o) => o.dx.isFinite && o.dy.isFinite;

void main() {
  group('T-0059-AC2 bar painter', () {
    test('T-0059-AC2 bars are drawn from the zero line, in data order', () {
      final painter = _bar(_bars([5, -5, 0, 10]));
      final c = _paint(painter);
      final rects = c.fillRects();
      final l = painter.layout(_size);
      expect(rects, hasLength(3), reason: 'the zero bar has no extent');
      final zero = c
          .lines()
          .where((l) => l.$3.strokeWidth == McBarPainter.zeroLineWidth)
          .toList();
      expect(zero, hasLength(1));
      final zy = zero.single.$1.dy;
      expect(zero.single.$2.dy, zy);
      expect(zero.single.$1.dx, l.plot.left);
      expect(zero.single.$2.dx, l.plot.right);
      expect(zy, l.geometry.zero);
      // 5 rises from the zero line, -5 hangs below it, 10 rises further
      expect(rects[0].bottom, zy);
      expect(rects[1].top, zy);
      expect(rects[1].height, closeTo(rects[0].height, 1e-9));
      expect(rects[2].bottom, zy);
      expect(rects[2].height, closeTo(rects[0].height * 2, 1e-9));
      expect(rects[0].left, lessThan(rects[1].left));
      expect(rects[1].left, lessThan(rects[2].left));
      expect(rects.map((r) => r.width).toSet(), hasLength(1));
      expect(zy, lessThan(l.plot.bottom));
      expect(zy, greaterThan(l.plot.top));
    });

    test('T-0059-AC2 the zero line is drawn over the bars', () {
      final c = _paint(_bar(_bars([5, 6])));
      final lastRect = c.calls.lastIndexWhere((x) => x.name == 'drawRect');
      final zero = c.calls.indexWhere(
        (x) =>
            x.name == 'drawLine' &&
            x.arg<Paint>(2).strokeWidth == McBarPainter.zeroLineWidth,
      );
      expect(zero, greaterThan(lastRect));
    });

    test('T-0059-AC2 bar colours come from the roles', () {
      final c = _paint(
        _bar(
          _bars(
            [1, 2, 3, 4],
            roles: [
              null,
              McChartRole.positive,
              McChartRole.negative,
              McChartRole.series3,
            ],
          ),
        ),
      );
      expect(
        _argbs(c.filledRects().map((r) => r.$2)),
        _argbs([
          _p.series1,
          _p.success,
          _p.error,
          _p.series3,
        ]),
      );
    });

    test('T-0059-AC2 grid lines sit on the ticks, not on the zero tick', () {
      final painter = _bar(_bars([0, 10]));
      final c = _paint(painter);
      final l = painter.layout(_size);
      final grid = c
          .lines()
          .where((x) => x.$3.strokeWidth == McBarPainter.gridLineWidth)
          .toList();
      final ticks = l.scale.ticks;
      expect(grid, hasLength(ticks.length - 1));
      expect(
        grid.map((g) => g.$1.dy).toList(),
        l.geometry.tickPositions.skip(1).toList(),
      );
      expect(c.textCount, ticks.length + 2);
    });

    test('T-0059-AC2 all-zero data draws no bar and no non-finite number', () {
      final c = _paint(_bar(_bars([0, 0, 0])));
      expect(c.fillRects(), isEmpty);
      for (final l in c.lines()) {
        expect(_finite(l.$1) && _finite(l.$2), isTrue);
      }
      expect(c.lines().where((l) => l.$3.strokeWidth == 1.5), hasLength(1));
    });

    test('T-0059-AC2 a single datum is one bar', () {
      final c = _paint(_bar(_bars([7])));
      final rects = c.fillRects();
      expect(rects, hasLength(1));
      expect(rects.single.width, greaterThan(0));
      expect(rects.single.height, greaterThan(0));
    });

    test('T-0059-AC2 a single negative datum hangs below the zero line', () {
      final painter = _bar(_bars([-7]));
      final c = _paint(painter);
      final r = c.fillRects().single;
      expect(r.top, painter.layout(_size).geometry.zero);
    });

    test('T-0059-AC2 the highlight outlines only the chosen bar', () {
      final c = _paint(_bar(_bars([1, 2, 3]), highlight: 1));
      final outlines = c
          .named('drawRect')
          .where((x) => x.arg<Paint>(1).style == PaintingStyle.stroke)
          .toList();
      expect(outlines, hasLength(1));
      expect(
        outlines.single.arg<Paint>(1).strokeWidth,
        McBarPainter.highlightWidth,
      );
      expect(_argb(outlines.single.arg<Paint>(1).color), _argb(_p.onSurface));
      expect(outlines.single.arg<Rect>(0), c.fillRects()[1].inflate(1));
      for (final bad in [null, -1, 3]) {
        final none = _paint(_bar(_bars([1, 2, 3]), highlight: bad));
        expect(
          none
              .named('drawRect')
              .where((x) => x.arg<Paint>(1).style == PaintingStyle.stroke),
          isEmpty,
        );
      }
    });

    test('T-0059-AC2 horizontal bars grow from a vertical zero line', () {
      final painter = _bar(_bars([5, -5, 10]), vertical: false);
      final c = _paint(painter);
      final rects = c.fillRects();
      final zero = c.lines().singleWhere(
        (l) => l.$3.strokeWidth == McBarPainter.zeroLineWidth,
      );
      expect(zero.$1.dx, zero.$2.dx);
      final zx = zero.$1.dx;
      expect(rects[0].left, zx);
      expect(rects[1].right, zx);
      expect(rects[2].left, zx);
      expect(rects[2].width, closeTo(rects[0].width * 2, 1e-9));
      expect(rects[0].top, lessThan(rects[1].top));
      expect(rects[1].top, lessThan(rects[2].top));
    });

    test('T-0059-AC2 progress shortens the bars', () {
      final full = _paint(_bar(_bars([10, 5]))).fillRects();
      final half = _paint(_bar(_bars([10, 5]), progress: 0.5)).fillRects();
      expect(half[0].height, closeTo(full[0].height / 2, 1e-9));
      expect(half[1].height, closeTo(full[1].height / 2, 1e-9));
      expect(half[0].bottom, full[0].bottom);
      expect(_paint(_bar(_bars([10]), progress: 0)).fillRects(), isEmpty);
    });

    test('T-0059-AC2 thirty bars: one rect each, labels thinned out', () {
      final painter = _bar(_bars(List.generate(30, (i) => i + 1.0)));
      final c = _paint(painter, const Size(320, 240));
      expect(c.fillRects(), hasLength(30));
      final l = painter.layout(const Size(320, 240));
      expect(c.textCount, lessThan(l.scale.ticks.length + 30));
      expect(c.textCount, greaterThan(l.scale.ticks.length));
    });

    test('T-0059-AC2 category labels never overlap or leave the canvas', () {
      for (final scale in [1.0, 2.0, 3.0]) {
        final painter = _bar(
          _bars(List.generate(30, (i) => i + 1.0)),
          scaler: TextScaler.linear(scale),
        );
        const size = Size(320, 240);
        final c = _paint(painter, size);
        final row = painter.layout(size).plot.bottom + 6;
        final labels = [
          for (final x in c.named('drawParagraph'))
            if (x.arg<Offset>(1).dy == row)
              (x.arg<Offset>(1).dx, x.arg<Paragraph>(0).longestLine),
        ]..sort((a, b) => a.$1.compareTo(b.$1));
        expect(labels, isNotEmpty, reason: 'scale $scale');
        for (var i = 0; i < labels.length; i++) {
          expect(labels[i].$1, greaterThanOrEqualTo(0));
          expect(labels[i].$1 + labels[i].$2, lessThanOrEqualTo(size.width));
          if (i > 0) {
            expect(
              labels[i].$1,
              greaterThanOrEqualTo(labels[i - 1].$1 + labels[i - 1].$2),
              reason: 'scale $scale label $i',
            );
          }
        }
      }
    });

    test('T-0059-AC2 a thinned-out label at the edge stays on the canvas', () {
      for (final scale in [2.0, 3.0]) {
        final painter = _bar(
          [
            for (var i = 0; i < 13; i++)
              McBarDatum(
                label: 'Durchschnittsgeschwindigkeit $i',
                value: i + 1.0,
              ),
          ],
          scaler: TextScaler.linear(scale),
        );
        const size = Size(320, 240);
        final c = _paint(painter, size);
        final row = painter.layout(size).plot.bottom + 6;
        for (final x in c.named('drawParagraph')) {
          final at = x.arg<Offset>(1);
          if (at.dy == row) {
            expect(at.dx, greaterThanOrEqualTo(0), reason: 'scale $scale');
            expect(
              at.dx + x.arg<Paragraph>(0).longestLine,
              lessThanOrEqualTo(size.width),
              reason: 'scale $scale',
            );
          }
        }
      }
    });

    test('T-0059-AC2 few bars keep every label', () {
      final painter = _bar(_bars([1, 2, 3, 4]));
      final c = _paint(painter);
      expect(c.textCount, painter.layout(_size).scale.ticks.length + 4);
    });

    test('T-0059-AC2 large text still lays out inside the canvas', () {
      final painter = _bar(
        _bars([1, 2, 3, 4, 5]),
        scaler: const TextScaler.linear(3),
      );
      final l = painter.layout(_size);
      expect(l.plot.width, greaterThan(0));
      expect(l.plot.height, greaterThan(0));
      expect(l.plot.right, lessThanOrEqualTo(_size.width));
      expect(l.plot.bottom, lessThanOrEqualTo(_size.height));
    });

    test('T-0059-AC2 empty data paints nothing', () {
      expect(_paint(_bar(const [])).calls, isEmpty);
      expect(_bar(const []).semanticsBuilder(_size), isEmpty);
    });

    test('T-0059-AC2 tiny canvas does not break the layout', () {
      final c = _paint(_bar(_bars([1, 2])), const Size(10, 10));
      for (final r in c.fillRects()) {
        expect(r.isFinite, isTrue);
      }
    });

    test('T-0059-AC4 each bar is a semantics node in data order', () {
      final nodes = _bar(_bars([5, -5, 0])).semanticsBuilder(_size);
      expect(nodes.map((n) => n.properties.label).toList(), [
        'L0: 5',
        'L1: -5',
        'L2: 0',
      ]);
      expect(
        nodes
            .map((n) => (n.properties.sortKey! as OrdinalSortKey).order)
            .toList(),
        [0, 1, 2],
      );
      expect(nodes[0].rect.left, lessThan(nodes[1].rect.left));
    });

    test('T-0059-AC4 horizontal bars are nodes top to bottom', () {
      final nodes = _bar(_bars([5, 6]), vertical: false).semanticsBuilder(
        _size,
      );
      expect(nodes[0].rect.top, lessThan(nodes[1].rect.top));
    });

    test('T-0059-AC2 repaint and semantics rebuild only on change', () {
      final a = _bar(_bars([1, 2]));
      expect(a.shouldRepaint(_bar(_bars([1, 2]))), isFalse);
      expect(a.shouldRepaint(_bar(_bars([1, 3]))), isTrue);
      expect(a.shouldRepaint(_bar(_bars([1, 2]), vertical: false)), isTrue);
      expect(a.shouldRepaint(_bar(_bars([1, 2]), highlight: 0)), isTrue);
      expect(a.shouldRepaint(_bar(_bars([1, 2]), progress: 0.3)), isTrue);
      expect(a.shouldRebuildSemantics(_bar(_bars([1, 2]))), isFalse);
      expect(a.shouldRebuildSemantics(_bar(_bars([1, 5]))), isTrue);
    });
  });

  McDonutPainter donut(
    List<double> v, {
    double progress = 1,
    double? minSweep,
    List<McChartRole?>? roles,
  }) => McDonutPainter(
    data: [
      for (var i = 0; i < v.length; i++)
        McDonutSegment(label: 'S$i', value: v[i], role: roles?[i]),
    ],
    palette: _p,
    valueFormatter: mcFormatValue,
    minSweep: minSweep ?? mcDonutMinSweep,
    progress: progress == 1
        ? kAlwaysCompleteAnimation
        : AlwaysStoppedAnimation(progress),
  );

  group('T-0059-AC2 donut painter', () {
    test('T-0059-AC2 the drawn arcs plus their gaps make a full turn', () {
      final p = donut([1, 2, 3]);
      final arcs = _paint(p, const Size.square(200)).arcs();
      expect(arcs, hasLength(3));
      var total = 0.0;
      for (final a in arcs) {
        total += a.$3 + McDonutPainter.gap;
      }
      expect(total, closeTo(2 * math.pi, 1e-9));
      expect(arcs[0].$2, closeTo(-math.pi / 2 + McDonutPainter.gap / 2, 1e-12));
      expect(arcs[0].$3, closeTo(2 * math.pi / 6 - McDonutPainter.gap, 1e-9));
      expect(
        arcs[1].$2,
        closeTo(arcs[0].$2 + arcs[0].$3 + McDonutPainter.gap, 1e-9),
      );
      expect(arcs[2].$3, closeTo(math.pi - McDonutPainter.gap, 1e-9));
    });

    test('T-0059-AC2 the minimum sweep keeps a tiny segment visible', () {
      final arcs = _paint(donut([1000, 1, 1]), const Size.square(200)).arcs();
      expect(arcs, hasLength(3));
      expect(arcs[1].$3, closeTo(mcDonutMinSweep - McDonutPainter.gap, 1e-9));
      expect(arcs[2].$3, closeTo(mcDonutMinSweep - McDonutPainter.gap, 1e-9));
      final small = _paint(
        donut([1000, 1, 1], minSweep: 0.01),
        const Size.square(200),
      ).arcs();
      expect(
        small[1].$3,
        closeTo(0.01, 1e-12),
      );
    });

    test('T-0059-AC2 a single segment is a closed ring without a gap', () {
      final arcs = _paint(donut([3]), const Size.square(200)).arcs();
      expect(arcs.single.$3, closeTo(2 * math.pi, 1e-12));
      expect(arcs.single.$2, closeTo(-math.pi / 2, 1e-12));
    });

    test('T-0059-AC2 zero segments are skipped', () {
      final arcs = _paint(donut([0, 5, 0, 5]), const Size.square(200)).arcs();
      expect(arcs, hasLength(2));
    });

    test('T-0059-AC2 all-zero data draws the empty track ring', () {
      final arcs = _paint(donut([0, 0]), const Size.square(200)).arcs();
      expect(arcs, hasLength(1));
      expect(arcs.single.$3, closeTo(2 * math.pi, 1e-12));
      expect(_argb(arcs.single.$4.color), _argb(_p.surfaceVariant));
    });

    test('T-0059-AC2 the ring is a centred stroke of the right width', () {
      final p = donut([1, 1]);
      final arcs = _paint(p, const Size.square(200)).arcs();
      final ring = p.ring(const Size.square(200));
      expect(ring.center, const Offset(100, 100));
      expect(ring.thickness, closeTo(28, 1e-9));
      expect(ring.radius, 86);
      expect(arcs.first.$1, Rect.fromCircle(center: ring.center, radius: 86));
      expect(arcs.first.$4.strokeWidth, closeTo(28, 1e-9));
      expect(arcs.first.$4.style, PaintingStyle.stroke);
      final small = p.ring(const Size.square(20));
      expect(small.thickness, 10);
      expect(small.radius, 5);
    });

    test('T-0059-AC2 colours come from the roles, then the cycle', () {
      final arcs = _paint(
        donut(
          [1, 1, 1, 1, 1],
          roles: [McChartRole.negative, null, null, null, null],
        ),
        const Size.square(200),
      ).arcs();
      expect(
        _argbs(arcs.map((a) => a.$4.color)),
        _argbs([
          _p.error,
          _p.series2,
          _p.series3,
          _p.outline,
          _p.series1,
        ]),
      );
    });

    test('T-0059-AC2 progress shrinks the swept angle', () {
      final half = _paint(
        donut([1, 1], progress: 0.5),
        const Size.square(200),
      ).arcs().where((a) => _argb(a.$4.color) != _argb(_p.surfaceVariant));
      var total = 0.0;
      for (final a in half) {
        total += a.$3 + McDonutPainter.gap;
      }
      expect(total, closeTo(math.pi, 1e-9));
    });

    test('T-0059-AC4 segments are semantics nodes in data order', () {
      final nodes = donut([1, 0, 2]).semanticsBuilder(const Size.square(200));
      expect(nodes.map((n) => n.properties.label).toList(), [
        'S0: 1',
        'S1: 0',
        'S2: 2',
      ]);
      expect(nodes[0].rect.size, const Size.square(28));
      expect(
        nodes[0].rect.center.dy,
        lessThan(100),
        reason: 'first segment is on top',
      );
      expect(donut(const []).semanticsBuilder(_size), isEmpty);
      expect(_paint(donut(const [])).calls, isEmpty);
    });

    test('T-0059-AC2 repaint rules', () {
      final a = donut([1, 2]);
      expect(a.shouldRepaint(donut([1, 2])), isFalse);
      expect(a.shouldRepaint(donut([1, 3])), isTrue);
      expect(a.shouldRepaint(donut([1, 2], minSweep: 0.3)), isTrue);
      expect(a.shouldRepaint(donut([1, 2], progress: 0.2)), isTrue);
      expect(a.shouldRebuildSemantics(donut([1, 2])), isFalse);
      expect(a.shouldRebuildSemantics(donut([2, 2])), isTrue);
    });
  });

  McLinePainter line(
    List<McLineSeries> series, {
    List<String> x = const ['a', 'b', 'c', 'd'],
    double progress = 1,
  }) => McLinePainter(
    xLabels: x,
    series: series,
    palette: _p,
    labelStyle: _style,
    textScaler: TextScaler.noScaling,
    valueFormatter: mcFormatValue,
    progress: progress == 1
        ? kAlwaysCompleteAnimation
        : AlwaysStoppedAnimation(progress),
  );

  group('T-0059-AC2 line painter', () {
    test('T-0059-AC2 one marker per point at the laid out position', () {
      final p = line([
        const McLineSeries(label: 'A', values: [1, 4, 2, 3]),
      ]);
      final c = _paint(p);
      final pts = p.pointsOf(0, _size).whereType<Offset>().toList();
      final circles = c.named('drawCircle').toList();
      expect(circles, hasLength(4));
      expect(circles.map((x) => x.arg<Offset>(0)).toList(), pts);
      expect(
        circles.every((x) => x.arg<double>(1) == McLinePainter.markerRadius),
        isTrue,
      );
      expect(_argb(circles.first.arg<Paint>(2).color), _argb(_p.series1));
      // higher value, higher on the canvas (smaller y); x grows
      expect(pts[1].dy, lessThan(pts[0].dy));
      expect(pts[2].dx, greaterThan(pts[1].dx));
      final path = c.named('drawPath').single;
      expect(path.arg<Paint>(1).strokeWidth, McLinePainter.lineWidth);
      expect(_argb(path.arg<Paint>(1).color), _argb(_p.series1));
    });

    test('T-0059-AC2 a gap breaks the line and draws no marker', () {
      final p = line(
        [
          const McLineSeries(label: 'A', values: [1, double.nan, 2, 3, 4]),
        ],
        x: const ['a', 'b', 'c', 'd', 'e'],
      );
      final c = _paint(p);
      expect(c.named('drawCircle'), hasLength(4));
      expect(
        c.named('drawPath'),
        hasLength(1),
        reason: 'the lone first point has no segment',
      );
      expect(p.pointsOf(0, _size)[1], isNull);
      final all = p.pointsOf(0, _size);
      expect(all.whereType<Offset>().every(_finite), isTrue);
    });

    test('T-0059-AC2 series differ in marker shape', () {
      final p = line([
        const McLineSeries(label: 'A', values: [1, 2, 3, 4]),
        const McLineSeries(label: 'B', values: [4, 3, 2, 1]),
        const McLineSeries(label: 'C', values: [2, 2, 3, 3]),
      ]);
      final c = _paint(p);
      expect(c.named('drawCircle'), hasLength(4));
      expect(c.fillRects(), hasLength(4));
      // 3 lines + 4 triangles
      expect(c.named('drawPath'), hasLength(7));
      final colors = c
          .named('drawPath')
          .map((x) => x.arg<Paint>(1).color)
          .toSet();
      expect(
        _argbs(colors),
        _argbs([_p.series1, _p.series2, _p.series3]).toSet(),
      );
    });

    test('T-0059-AC2 a single point draws a marker and no line', () {
      final p = line(
        [
          const McLineSeries(label: 'A', values: [3]),
        ],
        x: const ['a'],
      );
      final c = _paint(p);
      expect(c.named('drawCircle'), hasLength(1));
      expect(c.named('drawPath'), isEmpty);
      final pt = p.pointsOf(0, _size).single!;
      expect(_finite(pt), isTrue);
    });

    test('T-0059-AC2 constant data does not divide by zero', () {
      final p = line([
        const McLineSeries(label: 'A', values: [5, 5, 5, 5]),
      ]);
      final pts = p.pointsOf(0, _size).whereType<Offset>().toList();
      expect(pts.every(_finite), isTrue);
      expect(pts.map((o) => o.dy).toSet(), hasLength(1));
    });

    test('T-0059-AC2 a range through zero draws the zero line', () {
      final p = line([
        const McLineSeries(label: 'A', values: [-3, 2, 4, -1]),
      ]);
      final c = _paint(p);
      expect(
        c.lines().where((l) => l.$3.strokeWidth == McLinePainter.zeroLineWidth),
        hasLength(1),
      );
      final flat = _paint(
        line([
          const McLineSeries(label: 'A', values: [3, 2, 4, 1]),
        ]),
      );
      expect(
        flat.lines().where(
          (l) => l.$3.strokeWidth == McLinePainter.zeroLineWidth,
        ),
        isEmpty,
      );
    });

    test('T-0059-AC2 progress lifts the points from the bottom', () {
      final s = [
        const McLineSeries(label: 'A', values: [1, 4, 2, 3]),
      ];
      final full = line(s).pointsOf(0, _size);
      final zero = line(s, progress: 0).pointsOf(0, _size);
      final plotBottom = line(s).layout(_size).plot.bottom;
      expect(zero.every((o) => o!.dy == plotBottom), isTrue);
      final half = line(s, progress: 0.5).pointsOf(0, _size);
      expect(half[1]!.dy, closeTo((plotBottom + full[1]!.dy) / 2, 1e-9));
      expect(half[1]!.dx, full[1]!.dx);
    });

    test('T-0059-AC2 x labels are thinned when they do not fit', () {
      final many = line([
        McLineSeries(
          label: 'A',
          values: List.generate(24, (i) => i.toDouble()),
        ),
      ], x: List.generate(24, (i) => 'Monat $i'));
      final few = line([
        const McLineSeries(label: 'A', values: [1, 2, 3, 4]),
      ]);
      final manyText = _paint(many).textCount;
      final fewText = _paint(few).textCount;
      expect(manyText, lessThan(24 + 6));
      expect(fewText, greaterThanOrEqualTo(4));
    });

    test('T-0059-AC4 each series is a semantics node with its values', () {
      final nodes = line(
        [
          const McLineSeries(label: 'A', values: [1, double.nan, 3]),
          const McLineSeries(label: 'B', values: [2]),
        ],
        x: const ['x', 'y', 'z'],
      ).semanticsBuilder(_size);
      expect(nodes.map((n) => n.properties.label).toList(), [
        'A: x 1, z 3',
        'B: x 2',
      ]);
      expect(line(const [], x: const []).semanticsBuilder(_size), isEmpty);
      expect(_paint(line(const [], x: const [])).calls, isEmpty);
    });

    test('T-0059-AC2 repaint rules', () {
      final s = [
        const McLineSeries(label: 'A', values: [1, 2, 3, 4]),
      ];
      final a = line(s);
      expect(
        a.shouldRepaint(
          line([
            const McLineSeries(label: 'A', values: [1, 2, 3, 4]),
          ]),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          line([
            const McLineSeries(label: 'A', values: [1, 2, 3, 5]),
          ]),
        ),
        isTrue,
      );
      expect(a.shouldRepaint(line(s, x: const ['a', 'b', 'c', 'e'])), isTrue);
      expect(a.shouldRebuildSemantics(line(s)), isFalse);
      expect(
        a.shouldRebuildSemantics(line(s, x: const ['q', 'b', 'c', 'd'])),
        isTrue,
      );
    });
  });

  McRadarPainter radar(
    List<McRadarSeries> series, {
    List<String> axes = const ['A', 'B', 'C', 'D', 'E'],
    double progress = 1,
  }) => McRadarPainter(
    axes: axes,
    series: series,
    palette: _p,
    labelStyle: _style,
    textScaler: TextScaler.noScaling,
    valueFormatter: mcFormatValue,
    progress: progress == 1
        ? kAlwaysCompleteAnimation
        : AlwaysStoppedAnimation(progress),
  );

  group('T-0059-AC2 radar painter', () {
    test('T-0059-AC2 rings, spokes and the series polygon', () {
      final p = radar([
        const McRadarSeries(label: 'S', values: [1, 0.5, 0, 1, 0.25]),
      ]);
      final c = _paint(p, const Size.square(280));
      // 4 rings + the series fill + the series outline
      expect(c.named('drawPath'), hasLength(6));
      expect(c.lines(), hasLength(5));
      final f = p.frame(const Size.square(280));
      for (final l in c.lines()) {
        expect(l.$1, f.center);
        expect((l.$2 - f.center).distance, closeTo(f.radius, 1e-9));
      }
      final circles = c
          .named('drawCircle')
          .map((x) => x.arg<Offset>(0))
          .toList();
      expect(circles, hasLength(5));
      expect(circles, p.polygonOf(0, const Size.square(280)));
      expect(circles[0].dy, lessThan(f.center.dy));
      expect(circles[2], f.center, reason: 'a 0 value sits on the centre');
      expect((circles[0] - f.center).distance, closeTo(f.radius, 1e-9));
      expect((circles[1] - f.center).distance, closeTo(f.radius / 2, 1e-9));
    });

    test('T-0059-AC2 the fill is translucent and the outline solid', () {
      final c = _paint(
        radar([
          const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
        ]),
        const Size.square(280),
      );
      final paths = c.named('drawPath').toList();
      final fill = paths[4].arg<Paint>(1);
      final stroke = paths[5].arg<Paint>(1);
      expect(fill.style, PaintingStyle.fill);
      expect(fill.color.a, closeTo(0.2, 0.01));
      expect(stroke.style, PaintingStyle.stroke);
      expect(_argb(stroke.color), _argb(_p.series1));
      expect(stroke.strokeWidth, McRadarPainter.seriesLineWidth);
    });

    test('T-0059-AC2 two series use the first two series colours', () {
      final c = _paint(
        radar([
          const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
          const McRadarSeries(label: 'T', values: [0.2, 0.2, 0.2, 0.2, 0.2]),
        ]),
        const Size.square(280),
      );
      expect(c.named('drawPath'), hasLength(8));
      final circleColors = c
          .named('drawCircle')
          .map((x) => x.arg<Paint>(2).color)
          .toList();
      expect(_argbs(circleColors.take(5)).toSet(), {_argb(_p.series1)});
      expect(_argbs(circleColors.skip(5)).toSet(), {_argb(_p.series2)});
    });

    test('T-0059-AC2 out-of-range and non-finite values stay on the chart', () {
      final p = radar([
        const McRadarSeries(
          label: 'S',
          values: [5, -2, double.nan, double.infinity, 0.5],
        ),
      ]);
      final pts = p.polygonOf(0, const Size.square(280));
      final f = p.frame(const Size.square(280));
      expect(pts.every(_finite), isTrue);
      expect((pts[0] - f.center).distance, closeTo(f.radius, 1e-9));
      expect(pts[1], f.center);
      expect(pts[2], f.center);
      expect(pts[3], f.center);
    });

    test('T-0059-AC2 a short series is padded with zeros', () {
      final p = radar([
        const McRadarSeries(label: 'S', values: [1, 1]),
      ]);
      final pts = p.polygonOf(0, const Size.square(280));
      expect(pts, hasLength(5));
      expect(pts[4], p.frame(const Size.square(280)).center);
    });

    test('T-0059-AC2 3 and 8 axes both close', () {
      for (final n in [3, 8]) {
        final p = radar(
          [McRadarSeries(label: 'S', values: List.filled(n, 1))],
          axes: List.generate(n, (i) => 'A$i'),
        );
        final c = _paint(p, const Size.square(280));
        expect(c.lines(), hasLength(n));
        expect(c.named('drawCircle'), hasLength(n));
        expect(c.textCount, n);
      }
    });

    test('T-0059-AC2 progress pulls the polygon to the centre', () {
      final s = [
        const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
      ];
      final half = radar(s, progress: 0.5).polygonOf(0, const Size.square(280));
      final f = radar(s).frame(const Size.square(280));
      for (final v in half) {
        expect((v - f.center).distance, closeTo(f.radius / 2, 1e-9));
      }
    });

    test('T-0059-AC2 the rim leaves room for labels and never collapses', () {
      final p = radar(const [
        McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
      ]);
      final f = p.frame(const Size.square(280));
      expect(f.radius, lessThan(140));
      expect(f.radius, greaterThan(40));
      expect(p.frame(const Size(10, 10)).radius, 8);
    });

    test('T-0059-AC4 each series is a semantics node in order', () {
      final nodes = radar([
        const McRadarSeries(label: 'S', values: [1, 0.5, 2, double.nan, 0]),
        const McRadarSeries(label: 'T', values: [0, 0, 0, 0, 0]),
      ]).semanticsBuilder(_size);
      expect(nodes[0].properties.label, 'S: A 1, B 0.5, C 1, D 0, E 0');
      expect(nodes[1].properties.label, startsWith('T: A 0'));
      expect(radar(const [], axes: const []).semanticsBuilder(_size), isEmpty);
      expect(_paint(radar(const [], axes: const [])).calls, isEmpty);
    });

    test('T-0059-AC2 repaint rules', () {
      final s = [
        const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
      ];
      final a = radar(s);
      expect(
        a.shouldRepaint(
          radar([
            const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 1]),
          ]),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          radar([
            const McRadarSeries(label: 'S', values: [1, 1, 1, 1, 0]),
          ]),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(radar(s, axes: const ['A', 'B', 'C', 'D', 'X'])),
        isTrue,
      );
      expect(a.shouldRebuildSemantics(radar(s)), isFalse);
      expect(
        a.shouldRebuildSemantics(
          radar(s, axes: const ['A', 'B', 'C', 'D', 'X']),
        ),
        isTrue,
      );
    });
  });

  group('T-0059-AC2 zero lines', () {
    List<(Offset, Offset, Paint)> zeroLines(RecordingCanvas c, double w) =>
        c.lines().where((l) => l.$3.strokeWidth == w).toList();

    test('T-0059-AC2 line: a zero line whenever 0 is on the axis', () {
      for (final values in [
        [0.0, 5.0, 10.0, 7.0],
        [-10.0, -4.0, 0.0, -7.0],
        [0.0, 0.0, 0.0, 0.0],
        [-3.0, 4.0, 1.0, 2.0],
      ]) {
        final p = line([McLineSeries(label: 'A', values: values)]);
        final c = _paint(p);
        final z = zeroLines(c, McLinePainter.zeroLineWidth);
        expect(z, hasLength(1), reason: '$values');
        final l = p.layout(_size);
        final y = l.plot.bottom - l.scale.fraction(0) * l.plot.height;
        expect(z.single.$1.dy, y);
        expect(z.single.$2.dy, y);
        expect(z.single.$1.dx, l.plot.left);
        expect(z.single.$2.dx, l.plot.right);
      }
    });

    test('T-0059-AC2 line: none when 0 is off the axis', () {
      for (final values in [
        [3.0, 5.0, 4.0, 8.0],
        [-9.0, -5.0, -4.0, -8.0],
      ]) {
        final c = _paint(line([McLineSeries(label: 'A', values: values)]));
        expect(zeroLines(c, McLinePainter.zeroLineWidth), isEmpty);
      }
    });

    test('T-0059-AC2 bars: the zero line exists for all-positive and all-negative data', () {
      for (final values in [
        [1.0, 5.0],
        [-1.0, -5.0],
        [0.0, 0.0],
      ]) {
        final c = _paint(_bar(_bars(values)));
        expect(zeroLines(c, McBarPainter.zeroLineWidth), hasLength(1));
      }
    });
  });

  group('T-0059-AC4 radar semantics', () {
    test(
      'T-0059-AC4 every axis is read, a missing value as 0 like the painter',
      () {
        final nodes = radar(
          [
            const McRadarSeries(label: 'S', values: [1, 0.5, 0.25]),
            const McRadarSeries(
              label: 'T',
              values: [2, double.nan, -1, 0.5, 0.5, 9],
            ),
          ],
          axes: const ['A', 'B', 'C', 'D', 'E'],
        ).semanticsBuilder(_size);
        expect(nodes[0].properties.label, 'S: A 1, B 0.5, C 0.25, D 0, E 0');
        expect(nodes[1].properties.label, 'T: A 1, B 0, C 0, D 0.5, E 0.5');
      },
    );
  });

  group('T-0059-AC4 value text', () {
    test('T-0059-AC4 no negative zero in value text', () {
      expect(mcFormatValue(-0.0), '0');
      expect(mcFormatValue(-0.001), '0');
      expect(mcFormatValue(0.001), '0');
      expect(mcFormatValue(-1.5), '-1.5');
      expect(mcFormatValue(-2), '-2');
      expect(mcFormatValue(0.005), '0.01');
    });
  });

  group('T-0059-AC2 timeline rail painter', () {
    McTimelineRailPainter rail({bool first = false, bool last = false}) =>
        McTimelineRailPainter(
          markerColor: _p.series2,
          lineColor: _p.outline,
          ringColor: _p.surface,
          markerY: 10,
          isFirst: first,
          isLast: last,
        );
    const size = Size(28, 80);

    test('T-0059-AC2 a middle event has a full-height line', () {
      final c = _paint(rail(), size);
      final l = c.lines().single;
      expect(l.$1, const Offset(14, 0));
      expect(l.$2, const Offset(14, 80));
      expect(_argb(l.$3.color), _argb(_p.outline));
      expect(l.$3.strokeWidth, McTimelineRailPainter.lineWidth);
    });

    test(
      'T-0059-AC2 the first line starts at its marker, the last ends there',
      () {
        final first = _paint(rail(first: true), size).lines().single;
        expect(first.$1, const Offset(14, 10));
        expect(first.$2, const Offset(14, 80));
        final last = _paint(rail(last: true), size).lines().single;
        expect(last.$1, const Offset(14, 0));
        expect(last.$2, const Offset(14, 10));
        expect(_paint(rail(first: true, last: true), size).lines(), isEmpty);
      },
    );

    test('T-0059-AC2 the marker is a ring and a dot in the role colour', () {
      final circles = _paint(rail(), size).named('drawCircle').toList();
      expect(circles, hasLength(2));
      expect(circles[0].arg<Offset>(0), const Offset(14, 10));
      expect(circles[0].arg<double>(1), McTimelineRailPainter.markerRadius + 2);
      expect(_argb(circles[0].arg<Paint>(2).color), _argb(_p.surface));
      expect(circles[1].arg<double>(1), McTimelineRailPainter.markerRadius);
      expect(_argb(circles[1].arg<Paint>(2).color), _argb(_p.series2));
    });

    test('T-0059-AC2 repaint rules', () {
      expect(rail().shouldRepaint(rail()), isFalse);
      expect(rail().shouldRepaint(rail(first: true)), isTrue);
      expect(rail().shouldRepaint(rail(last: true)), isTrue);
      expect(
        rail().shouldRepaint(
          McTimelineRailPainter(
            markerColor: _p.series1,
            lineColor: _p.outline,
            ringColor: _p.surface,
            markerY: 10,
            isFirst: false,
            isLast: false,
          ),
        ),
        isTrue,
      );
      expect(
        rail().shouldRepaint(
          McTimelineRailPainter(
            markerColor: _p.series2,
            lineColor: _p.outline,
            ringColor: _p.surface,
            markerY: 12,
            isFirst: false,
            isLast: false,
          ),
        ),
        isTrue,
      );
    });
  });
}
