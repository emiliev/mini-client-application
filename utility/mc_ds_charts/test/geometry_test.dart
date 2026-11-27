// T-0059-AC2 (pure geometry) and the colour roles of T-0059-AC4.
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';
import 'package:mc_ds_charts/src/chart_common.dart';
import 'package:mc_ds_charts/src/chart_math.dart'
    show mcLabelStride, mcSlotCenter;
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

const _full = 2 * math.pi;

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('T-0059-AC2 nice ticks', () {
    test('T-0059-AC2 zero data gives 0..1 on 0.5 steps', () {
      final s = mcNiceTicks(0, 0, includeZero: true);
      expect(s.ticks, [0, 0.5, 1]);
      expect(s.step, 0.5);
    });

    test('T-0059-AC2 1-2-5 steps for a spread of ranges', () {
      expect(mcNiceTicks(0, 10).ticks, [0, 5, 10]);
      expect(mcNiceTicks(0, 100).ticks, [0, 50, 100]);
      expect(mcNiceTicks(0, 8).ticks, [0, 2, 4, 6, 8]);
      expect(mcNiceTicks(0, 7).step, 2);
      expect(mcNiceTicks(0, 3).ticks, [0, 1, 2, 3]);
      expect(mcNiceTicks(0, 45).step, 20);
      expect(mcNiceTicks(0, 450).step, 200);
      expect(mcNiceTicks(0, 0.8).step, 0.2);
    });

    test('T-0059-AC2 the step helper rounds up to 1, 2, 5 or 10', () {
      expect(mcNiceStep(1), 1);
      expect(mcNiceStep(1.01), 2);
      expect(mcNiceStep(2), 2);
      expect(mcNiceStep(2.01), 5);
      expect(mcNiceStep(5), 5);
      expect(mcNiceStep(5.01), 10);
      expect(mcNiceStep(0.07), 0.1);
      expect(mcNiceStep(1000), 1000);
      expect(mcNiceStep(0.001), 0.001);
    });

    test('T-0059-AC2 ticks cover the data and stay on the step', () {
      for (final (lo, hi) in [
        (3.0, 97.0),
        (-12.0, 40.0),
        (0.2, 0.9),
        (-1.0, 1.0),
        (1234.0, 98765.0),
      ]) {
        final s = mcNiceTicks(lo, hi);
        expect(s.min, lessThanOrEqualTo(lo));
        expect(s.max, greaterThanOrEqualTo(hi));
        expect(s.count, lessThanOrEqualTo(8));
        for (final t in s.ticks) {
          final q = t / s.step;
          expect((q - q.roundToDouble()).abs(), lessThan(1e-9));
        }
      }
    });

    test('T-0059-AC2 negative ranges include the zero', () {
      final s = mcNiceTicks(-30, -5, includeZero: true);
      expect(s.ticks, [-30, -20, -10, 0]);
      final sym = mcNiceTicks(-5, 5);
      expect(sym.ticks, [-5, 0, 5]);
    });

    test('T-0059-AC2 a single value gets its own range', () {
      expect(mcNiceTicks(7, 7, includeZero: true).ticks, [0, 2, 4, 6, 8]);
      final free = mcNiceTicks(7, 7);
      expect(free.min, lessThan(7));
      expect(free.max, greaterThan(7));
      expect(free.step, greaterThan(0));
      final neg = mcNiceTicks(-6, -6, includeZero: true);
      expect(neg.min, -6);
      expect(neg.max, 0);
    });

    test('T-0059-AC2 huge and tiny ranges', () {
      expect(mcNiceTicks(0, 1e12).ticks, [0, 5e11, 1e12]);
      expect(mcNiceTicks(0, 3e-9).ticks, [0, 1e-9, 2e-9, 3e-9]);
      expect(mcNiceTicks(0, 0.3).ticks, [0, 0.1, 0.2, 0.3]);
      final big = mcNiceTicks(-1e300, 1e300);
      expect(big.step.isFinite, isTrue);
    });

    test('T-0059-AC2 bad bounds are rejected', () {
      expect(() => mcNiceTicks(double.nan, 1), throwsArgumentError);
      expect(() => mcNiceTicks(0, double.infinity), throwsArgumentError);
      expect(() => mcNiceTicks(5, 1), throwsArgumentError);
      expect(() => mcNiceTicks(0, 1, targetTicks: 1), throwsArgumentError);
    });

    test('T-0059-AC2 target ticks change the density', () {
      expect(
        mcNiceTicks(0, 100, targetTicks: 11).step,
        lessThan(mcNiceTicks(0, 100, targetTicks: 3).step),
      );
    });

    test('T-0059-AC2 the scale maps values to fractions', () {
      final s = mcNiceTicks(0, 10);
      expect(s.fraction(0), 0);
      expect(s.fraction(10), 1);
      expect(s.fraction(2.5), 0.25);
      expect(s.span, 10);
      expect(s, mcNiceTicks(0, 10));
      expect(s.hashCode, mcNiceTicks(0, 10).hashCode);
    });

    test('T-0059-AC2 tick and value formatting', () {
      expect(mcFormatTick(20, step: 20), '20');
      expect(mcFormatTick(0.2, step: 0.1), '0.2');
      expect(mcFormatTick(0.25, step: 0.05), '0.25');
      expect(mcFormatTick(0.000002, step: 0.000001), '0.000002');
      expect(mcFormatTick(-0.0, step: 0.5), '0.0');
      expect(mcFormatValue(12), '12');
      expect(mcFormatValue(1.5), '1.5');
      expect(mcFormatValue(1.25), '1.25');
      expect(mcFormatValue(0.1 + 0.2), '0.3');
    });

    test('T-0059-AC2 tick count follows the room, between 3 and 6', () {
      expect(mcTickCountFor(100, 100), 3);
      expect(mcTickCountFor(250, 100), 3);
      expect(mcTickCountFor(450, 100), 4);
      expect(mcTickCountFor(300, 50), 6);
      expect(mcTickCountFor(160, 40), 4);
      expect(mcTickCountFor(9999, 1), 6);
    });
  });

  group('T-0059-AC2 bar extents', () {
    const plot = Rect.fromLTRB(10, 20, 110, 120);

    test('T-0059-AC2 vertical bars rise from the bottom for positive data', () {
      final scale = mcNiceTicks(0, 10, includeZero: true);
      final g = mcLayoutBars(
        plot: plot,
        values: [5, 10, 0],
        scale: scale,
        vertical: true,
      );
      expect(g.zero, 120);
      final slot = 100 / 3;
      final w = slot * 0.7;
      expect(g.bars[0].left, closeTo(10 + (slot - w) / 2, 1e-9));
      expect(g.bars[0].width, closeTo(w, 1e-9));
      expect(g.bars[0].top, 70);
      expect(g.bars[0].bottom, 120);
      expect(g.bars[1].top, 20);
      expect(g.bars[2].height, 0);
      expect(g.bars[1].left, closeTo(10 + slot + (slot - w) / 2, 1e-9));
    });

    test('T-0059-AC2 negative values hang below the zero line', () {
      final scale = mcNiceTicks(-10, 10);
      expect(scale.min, -10);
      final g = mcLayoutBars(
        plot: plot,
        values: [-5, 5],
        scale: scale,
        vertical: true,
      );
      expect(g.zero, 70);
      expect(g.bars[0].top, 70);
      expect(g.bars[0].bottom, 95);
      expect(g.bars[1].top, 45);
      expect(g.bars[1].bottom, 70);
    });

    test('T-0059-AC2 a negative-only range keeps zero at the top', () {
      final scale = mcNiceTicks(-8, -2, includeZero: true);
      final g = mcLayoutBars(
        plot: plot,
        values: [-8, -2],
        scale: scale,
        vertical: true,
      );
      expect(scale.max, 0);
      expect(g.zero, plot.top);
      expect(g.bars[0].bottom, plot.bottom);
      expect(g.bars[1].top, plot.top);
      expect(g.bars[1].bottom, closeTo(plot.top + 0.25 * plot.height, 1e-9));
    });

    test('T-0059-AC2 horizontal bars grow right and left of the zero line', () {
      final scale = mcNiceTicks(-10, 10);
      final g = mcLayoutBars(
        plot: plot,
        values: [5, -5],
        scale: scale,
        vertical: false,
      );
      expect(g.zero, 60);
      expect(g.bars[0].left, 60);
      expect(g.bars[0].right, 85);
      expect(g.bars[1].left, 35);
      expect(g.bars[1].right, 60);
      expect(g.bars[0].top, lessThan(g.bars[1].top));
      expect(g.bars[0].height, closeTo(50 * 0.7, 1e-9));
    });

    test('T-0059-AC2 tick positions follow the ticks', () {
      final scale = mcNiceTicks(0, 10);
      final g = mcLayoutBars(
        plot: plot,
        values: [1],
        scale: scale,
        vertical: true,
      );
      expect(g.tickPositions, [120, 70, 20]);
    });

    test('T-0059-AC2 progress scales the bar length', () {
      final scale = mcNiceTicks(0, 10);
      final g = mcLayoutBars(
        plot: plot,
        values: [10, -0.0],
        scale: scale,
        vertical: true,
        progress: 0.5,
      );
      expect(g.bars[0].top, 70);
      final none = mcLayoutBars(
        plot: plot,
        values: [10],
        scale: scale,
        vertical: true,
        progress: 0,
      );
      expect(none.bars[0].height, 0);
    });

    test('T-0059-AC2 many bars stay at least one logical pixel wide', () {
      final g = mcLayoutBars(
        plot: const Rect.fromLTWH(0, 0, 20, 100),
        values: List.filled(30, 1),
        scale: mcNiceTicks(0, 1),
        vertical: true,
      );
      expect(g.bars, hasLength(30));
      expect(g.bars.every((b) => b.width >= 1 - 1e-9), isTrue);
    });

    test('T-0059-AC2 no bars still lays out', () {
      final g = mcLayoutBars(
        plot: plot,
        values: const [],
        scale: mcNiceTicks(0, 0, includeZero: true),
        vertical: true,
      );
      expect(g.bars, isEmpty);
    });
  });

  group('T-0059-AC2 donut sweeps', () {
    double sum(List<double> l) => l.fold(0.0, (a, b) => a + b);

    test('T-0059-AC2 sweeps are proportional and sum to 360 degrees', () {
      final s = mcDonutSweeps([1, 1, 2]);
      expect(sum(s), closeTo(_full, 1e-9));
      expect(s[0], closeTo(_full / 4, 1e-9));
      expect(s[2], closeTo(_full / 2, 1e-9));
    });

    test('T-0059-AC2 a tiny segment is raised to the minimum sweep', () {
      final s = mcDonutSweeps([1000, 1, 1]);
      expect(s[1], closeTo(mcDonutMinSweep, 1e-12));
      expect(s[2], closeTo(mcDonutMinSweep, 1e-12));
      expect(s[0], closeTo(_full - 2 * mcDonutMinSweep, 1e-9));
      expect(sum(s), closeTo(_full, 1e-9));
    });

    test('T-0059-AC2 the default minimum is 4 degrees', () {
      expect(mcDonutMinSweep, closeTo(4 * math.pi / 180, 1e-15));
    });

    test(
      'T-0059-AC2 raising one segment can push another under; it repeats',
      () {
        final s = mcDonutSweeps([10, 1, 1, 0.1], minSweep: 0.5);
        expect(s[3], 0.5);
        expect(s[1], 0.5);
        expect(s[2], 0.5);
        expect(s[0], closeTo(_full - 1.5, 1e-9));
        expect(sum(s), closeTo(_full, 1e-9));
      },
    );

    test('T-0059-AC2 a value above the minimum is not raised', () {
      final s = mcDonutSweeps([10, 1], minSweep: 0.1);
      expect(s[1], closeTo(_full / 11, 1e-9));
    });

    test('T-0059-AC2 zero values stay at zero sweep', () {
      final s = mcDonutSweeps([0, 3, 0, 1]);
      expect(s[0], 0);
      expect(s[2], 0);
      expect(sum(s), closeTo(_full, 1e-9));
    });

    test('T-0059-AC2 all-zero and empty data have no sweep', () {
      expect(mcDonutSweeps([0, 0, 0]), [0, 0, 0]);
      expect(mcDonutSweeps(const []), isEmpty);
    });

    test('T-0059-AC2 a single value is a full turn', () {
      expect(mcDonutSweeps([5]), [closeTo(_full, 1e-12)]);
      expect(mcDonutSweeps([0.0001]), [closeTo(_full, 1e-12)]);
    });

    test('T-0059-AC2 too many segments for the minimum share the turn', () {
      final s = mcDonutSweeps(List.filled(20, 1), minSweep: 0.5);
      expect(s, everyElement(closeTo(_full / 20, 1e-12)));
      expect(sum(s), closeTo(_full, 1e-9));
    });

    test('T-0059-AC2 sums hold for many random-ish inputs', () {
      final rnd = math.Random(59);
      for (var i = 0; i < 200; i++) {
        final n = 1 + rnd.nextInt(12);
        final values = [
          for (var k = 0; k < n; k++)
            rnd.nextInt(4) == 0
                ? 0.0
                : math.pow(10, rnd.nextInt(6) - 2) * rnd.nextDouble(),
        ];
        final s = mcDonutSweeps(values);
        final positives = values.where((v) => v > 0).length;
        if (positives == 0) {
          expect(sum(s), 0);
          continue;
        }
        expect(sum(s), closeTo(_full, 1e-9), reason: '$values');
        for (var k = 0; k < n; k++) {
          if (values[k] > 0) {
            expect(
              s[k],
              greaterThanOrEqualTo(
                math.min(mcDonutMinSweep, _full / positives) - 1e-12,
              ),
            );
          } else {
            expect(s[k], 0);
          }
        }
      }
    });

    test('T-0059-AC2 arcs run clockwise from 12 oclock', () {
      final arcs = mcDonutArcs([1, 2, 3]);
      expect(arcs[0], const McArc(-math.pi / 2, 1));
      expect(arcs[1].start, closeTo(-math.pi / 2 + 1, 1e-12));
      expect(arcs[2].start, closeTo(-math.pi / 2 + 3, 1e-12));
      expect(arcs[2].end, closeTo(-math.pi / 2 + 6, 1e-12));
      expect(arcs[1].mid, closeTo(-math.pi / 2 + 2, 1e-12));
      expect(arcs[0], const McArc(-math.pi / 2, 1));
      expect(arcs[0].hashCode, const McArc(-math.pi / 2, 1).hashCode);
      expect(mcDonutArcs([1], startAngle: 0).single.start, 0);
      expect(arcs[0].toString(), contains('McArc'));
    });
  });

  group('T-0059-AC2 radar vertices', () {
    test('T-0059-AC2 axis 0 points up and the axes run clockwise', () {
      Offset v(int i, double value) => mcRadarVertex(
        center: const Offset(100, 100),
        radius: 50,
        index: i,
        count: 4,
        value: value,
      );
      expect(v(0, 1).dx, closeTo(100, 1e-9));
      expect(v(0, 1).dy, closeTo(50, 1e-9));
      expect(v(1, 1).dx, closeTo(150, 1e-9));
      expect(v(1, 1).dy, closeTo(100, 1e-9));
      expect(v(2, 1).dy, closeTo(150, 1e-9));
      expect(v(3, 1).dx, closeTo(50, 1e-9));
    });

    test('T-0059-AC2 the value scales the distance from the centre', () {
      final p = mcRadarVertex(
        center: const Offset(10, 10),
        radius: 40,
        index: 1,
        count: 4,
        value: 0.5,
      );
      expect(p.dx, closeTo(30, 1e-9));
      expect(p.dy, closeTo(10, 1e-9));
      final zero = mcRadarVertex(
        center: const Offset(10, 10),
        radius: 40,
        index: 2,
        count: 5,
        value: 0,
      );
      expect(zero, const Offset(10, 10));
    });

    test('T-0059-AC2 values are clamped to 0..1', () {
      Offset v(double value) => mcRadarVertex(
        center: Offset.zero,
        radius: 10,
        index: 1,
        count: 4,
        value: value,
      );
      expect(v(5).dx, closeTo(10, 1e-9));
      expect(v(-3), Offset.zero);
    });

    test('T-0059-AC2 the vertices of 3 to 8 axes sit on the rim, evenly', () {
      for (var n = 3; n <= 8; n++) {
        final pts = [
          for (var i = 0; i < n; i++)
            mcRadarVertex(
              center: Offset.zero,
              radius: 10,
              index: i,
              count: n,
              value: 1,
            ),
        ];
        for (final p in pts) {
          expect(p.distance, closeTo(10, 1e-9));
        }
        final d = (pts[1] - pts[0]).distance;
        for (var i = 1; i < n; i++) {
          expect((pts[(i + 1) % n] - pts[i]).distance, closeTo(d, 1e-9));
        }
      }
    });
  });

  group('T-0059-AC2 label helpers', () {
    test('T-0059-AC2 slot centres and label stride', () {
      expect(mcSlotCenter(0, 100, 0, 4), 12.5);
      expect(mcSlotCenter(0, 100, 3, 4), 87.5);
      expect(mcSlotCenter(10, 20, 0, 0), 15);
      expect(mcLabelStride(50, 100), 1);
      expect(mcLabelStride(100, 50), 2);
      expect(mcLabelStride(101, 50), 3);
      expect(mcLabelStride(10, 0), 1);
    });

    test('T-0059-AC2 doubles compare with NaN equal to NaN', () {
      expect(mcSameDoubles([1, double.nan], [1, double.nan]), isTrue);
      expect(mcSameDoubles([1, 2], [1, 3]), isFalse);
      expect(mcSameDoubles([1], [1, 1]), isFalse);
      expect(mcSameDoubles([1, double.nan], [double.nan, 1]), isFalse);
    });
  });

  group('T-0059-AC4 colour roles', () {
    test(
      'T-0059-AC4 every series and role colour reaches 3:1 on the surface',
      () {
        for (final variant in McThemeVariant.values) {
          final p = McPalette.of(variant);
          for (final role in McChartRole.values) {
            expect(
              _ratio(role.resolve(p), p.surface),
              greaterThanOrEqualTo(3),
              reason: '${role.name} in ${variant.name}',
            );
          }
        }
      },
    );

    test('T-0059-AC4 roles resolve to the palette fields', () {
      for (final variant in McThemeVariant.values) {
        final p = McPalette.of(variant);
        expect(McChartRole.series1.resolve(p), p.series1);
        expect(McChartRole.series2.resolve(p), p.series2);
        expect(McChartRole.series3.resolve(p), p.series3);
        expect(McChartRole.positive.resolve(p), p.success);
        expect(McChartRole.negative.resolve(p), p.error);
        expect(McChartRole.neutral.resolve(p), p.outline);
      }
    });

    test('T-0059-AC4 the three series colours differ in every theme', () {
      for (final variant in McThemeVariant.values) {
        final p = McPalette.of(variant);
        expect({p.series1, p.series2, p.series3}, hasLength(3));
        expect({p.series1, p.success, p.error, p.outline}, hasLength(4));
      }
    });

    test('T-0059-AC4 the default cycle starts with the series colours', () {
      expect(McChartRole.forIndex(0), McChartRole.series1);
      expect(McChartRole.forIndex(1), McChartRole.series2);
      expect(McChartRole.forIndex(2), McChartRole.series3);
      expect(McChartRole.forIndex(3), McChartRole.neutral);
      expect(McChartRole.forIndex(4), McChartRole.series1);
    });

    test('T-0059-AC4 the palette interpolates its series colours', () {
      final a = McPalette.light;
      final b = McPalette.dark;
      expect(McPalette.lerp(a, b, 0), a);
      expect(McPalette.lerp(a, b, 1), b);
      final mid = McPalette.lerp(a, b, 0.5);
      expect(mid.series1, Color.lerp(a.series1, b.series1, 0.5));
      expect(mid.series2, Color.lerp(a.series2, b.series2, 0.5));
      expect(mid.series3, Color.lerp(a.series3, b.series3, 0.5));
      expect(a == McPalette.light, isTrue);
      expect(
        McPalette.of(McThemeVariant.light) == McPalette.of(McThemeVariant.dark),
        isFalse,
      );
    });
  });
}
