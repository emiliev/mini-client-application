import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// A value axis: the first and last tick and the step between them.
///
/// Built by [mcNiceTicks]; every tick is a multiple of [step] (1, 2 or 5
/// times a power of ten).
@immutable
class McTickScale {
  const McTickScale({required this.min, required this.max, required this.step});

  final double min;
  final double max;
  final double step;

  /// Distance between the first and the last tick. Never zero.
  double get span => max - min;

  /// Number of ticks, ends included.
  int get count => (span / step).round() + 1;

  /// The tick values, lowest first, cleaned of floating-point noise.
  List<double> get ticks => [
    for (var i = 0; i < count; i++) _clean(min + i * step),
  ];

  /// Where [value] sits on the axis: 0 at [min], 1 at [max] (not clamped).
  double fraction(double value) => (value - min) / span;

  @override
  bool operator ==(Object other) =>
      other is McTickScale &&
      other.min == min &&
      other.max == max &&
      other.step == step;

  @override
  int get hashCode => Object.hash(min, max, step);

  @override
  String toString() => 'McTickScale($min..$max step $step)';
}

double _clean(double v) => double.parse(v.toStringAsPrecision(12));

/// The 1-2-5 step that is at least [raw] (so the axis never has more ticks
/// than asked for).
double mcNiceStep(double raw) {
  assert(raw > 0 && raw.isFinite, 'raw step must be positive and finite');
  final exponent = (math.log(raw) / math.ln10).floor();
  final magnitude = math.pow(10, exponent).toDouble();
  final f = raw / magnitude;
  final nice = f <= 1 + 1e-9
      ? 1
      : f <= 2 + 1e-9
      ? 2
      : f <= 5 + 1e-9
      ? 5
      : 10;
  return nice * magnitude;
}

/// Computes a value axis that covers [dataMin]..[dataMax] with about
/// [targetTicks] ticks on 1-2-5 steps.
///
/// - [includeZero] (bars) widens the range to contain 0.
/// - A single value (or all-equal values) gets a range of its own: with
///   [includeZero] it runs from 0 to the value, otherwise it is padded by half
///   its magnitude (by 1 for 0), so the step is never zero.
/// - Both bounds must be finite and `dataMin <= dataMax` (callers sanitise
///   first); otherwise an [ArgumentError] is thrown.
McTickScale mcNiceTicks(
  double dataMin,
  double dataMax, {
  int targetTicks = 5,
  bool includeZero = false,
}) {
  if (!dataMin.isFinite || !dataMax.isFinite) {
    throw ArgumentError('Tick bounds must be finite: $dataMin, $dataMax');
  }
  if (dataMin > dataMax) {
    throw ArgumentError('dataMin $dataMin is above dataMax $dataMax');
  }
  if (targetTicks < 2) {
    throw ArgumentError.value(targetTicks, 'targetTicks', 'must be >= 2');
  }
  var lo = includeZero ? math.min(dataMin, 0.0) : dataMin;
  var hi = includeZero ? math.max(dataMax, 0.0) : dataMax;
  if (lo == hi) {
    if (lo == 0) {
      hi = 1;
    } else {
      final pad = lo.abs() / 2;
      lo -= pad;
      hi += pad;
    }
  }
  final step = mcNiceStep((hi - lo) / (targetTicks - 1));
  final niceMin = _clean((lo / step + 1e-9).floorToDouble() * step);
  final niceMax = _clean((hi / step - 1e-9).ceilToDouble() * step);
  return McTickScale(
    min: niceMin,
    max: niceMax == niceMin ? niceMin + step : niceMax,
    step: step,
  );
}

/// Formats a tick or a value: whole numbers without decimals, otherwise as
/// many decimals as [step] needs (at most 6).
String mcFormatTick(double value, {double step = 1}) {
  final v = value == 0 ? 0.0 : value;
  if (step >= 1) {
    return v.toStringAsFixed(0);
  }
  final decimals = (-(math.log(step) / math.ln10)).ceil().clamp(1, 6);
  return v.toStringAsFixed(decimals);
}

/// The default value text of the semantics and legends: whole numbers as is,
/// otherwise up to two decimals without trailing zeros.
String mcFormatValue(double value) {
  if (value == value.roundToDouble()) {
    return (value == 0 ? 0.0 : value).toStringAsFixed(0);
  }
  final s = value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return s == '-0' ? '0' : s;
}

/// The rectangles of a bar chart and the position of its zero line.
@immutable
class McBarGeometry {
  const McBarGeometry({
    required this.bars,
    required this.zero,
    required this.tickPositions,
  });

  /// One rect per value, in data order. A zero value gives a zero-extent rect
  /// on the zero line.
  final List<Rect> bars;

  /// The zero line's coordinate on the value axis: a y (vertical bars) or an
  /// x (horizontal bars).
  final double zero;

  /// The coordinate of each tick on the value axis, in tick order.
  final List<double> tickPositions;
}

/// Places the bars of [values] inside [plot].
///
/// [vertical] bars rise from the zero line (negative values hang below it);
/// horizontal bars grow right from it (negative ones to its left). Bars share
/// the cross axis equally; [gapFraction] of each slot is left empty. [progress]
/// (0..1) scales every bar's length for the animation.
McBarGeometry mcLayoutBars({
  required Rect plot,
  required List<double> values,
  required McTickScale scale,
  required bool vertical,
  double gapFraction = 0.3,
  double progress = 1,
}) {
  double along(double v) => vertical
      ? plot.bottom - scale.fraction(v) * plot.height
      : plot.left + scale.fraction(v) * plot.width;
  final zero = along(0);
  final n = values.length;
  final slot = (vertical ? plot.width : plot.height) / math.max(n, 1);
  final thickness = math.max(1.0, slot * (1 - gapFraction));
  final bars = <Rect>[];
  for (var i = 0; i < n; i++) {
    final end = zero + (along(values[i]) - zero) * progress;
    final start =
        (vertical ? plot.left : plot.top) + i * slot + (slot - thickness) / 2;
    bars.add(
      vertical
          ? Rect.fromLTRB(
              start,
              math.min(end, zero),
              start + thickness,
              math.max(end, zero),
            )
          : Rect.fromLTRB(
              math.min(end, zero),
              start,
              math.max(end, zero),
              start + thickness,
            ),
    );
  }
  return McBarGeometry(
    bars: bars,
    zero: zero,
    tickPositions: [for (final t in scale.ticks) along(t)],
  );
}

/// One donut segment's arc, in radians clockwise from [start].
@immutable
class McArc {
  const McArc(this.start, this.sweep);

  final double start;
  final double sweep;

  double get end => start + sweep;
  double get mid => start + sweep / 2;

  @override
  bool operator ==(Object other) =>
      other is McArc && other.start == start && other.sweep == sweep;

  @override
  int get hashCode => Object.hash(start, sweep);

  @override
  String toString() => 'McArc($start, $sweep)';
}

/// The default smallest sweep of a non-zero donut segment: 4 degrees.
const double mcDonutMinSweep = 4 * math.pi / 180;

/// The sweeps (radians) of donut segments for [values] (all >= 0, finite).
///
/// - They sum to a full turn (2 pi) whenever any value is positive; they are
///   all 0 when the total is 0.
/// - A positive value never gets less than [minSweep], so a tiny segment stays
///   visible: it is raised to [minSweep] and the others give up the difference
///   in proportion to their size. Raising may push another segment below the
///   minimum, so this repeats until it is stable. When even [minSweep] for
///   every positive segment does not fit, they share the turn equally.
/// - A zero value always gets a zero sweep.
List<double> mcDonutSweeps(
  List<double> values, {
  double minSweep = mcDonutMinSweep,
}) {
  const full = 2 * math.pi;
  final positive = <int>[
    for (var i = 0; i < values.length; i++)
      if (values[i] > 0) i,
  ];
  final sweeps = List<double>.filled(values.length, 0);
  if (positive.isEmpty) {
    return sweeps;
  }
  if (positive.length * minSweep >= full) {
    for (final i in positive) {
      sweeps[i] = full / positive.length;
    }
    return sweeps;
  }
  final pinned = <int>{};
  while (true) {
    final free = [
      for (final i in positive)
        if (!pinned.contains(i)) i,
    ];
    final freeTotal = free.fold<double>(0, (a, i) => a + values[i]);
    final available = full - pinned.length * minSweep;
    var changed = false;
    for (final i in free) {
      if (values[i] / freeTotal * available < minSweep) {
        pinned.add(i);
        changed = true;
      }
    }
    if (!changed) {
      for (final i in positive) {
        sweeps[i] = pinned.contains(i)
            ? minSweep
            : values[i] / freeTotal * available;
      }
      break;
    }
  }
  return sweeps;
}

/// The arcs for [sweeps], starting at [startAngle] (default: 12 o'clock).
List<McArc> mcDonutArcs(
  List<double> sweeps, {
  double startAngle = -math.pi / 2,
}) {
  final arcs = <McArc>[];
  var at = startAngle;
  for (final s in sweeps) {
    arcs.add(McArc(at, s));
    at += s;
  }
  return arcs;
}

/// The vertex of radar axis [index] (of [count]) for a [value] of 0..1, from
/// [center] with the outer ring at [radius]. Axis 0 points up; the axes run
/// clockwise. [value] is clamped to 0..1.
Offset mcRadarVertex({
  required Offset center,
  required double radius,
  required int index,
  required int count,
  required double value,
}) {
  final angle = -math.pi / 2 + index * 2 * math.pi / count;
  final r = radius * value.clamp(0.0, 1.0);
  return Offset(
    center.dx + r * math.cos(angle),
    center.dy + r * math.sin(angle),
  );
}

/// The x of the point for slot [index] of [count] across [left]..[right]
/// (slot centres, like bars).
double mcSlotCenter(double left, double right, int index, int count) =>
    left + (index + 0.5) * (right - left) / math.max(count, 1);

/// How many labels to skip between drawn ones so that labels of
/// [labelWidth] fit in slots of [slotWidth]. 1 draws every label.
int mcLabelStride(double labelWidth, double slotWidth) {
  if (slotWidth <= 0) {
    return 1;
  }
  return math.max(1, (labelWidth / slotWidth).ceil());
}
