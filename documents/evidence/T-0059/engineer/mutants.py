"""Mutant table for T-0059 (mc_ds_charts). Used by mutations.sh.

Each mutant: (name, file relative to the repo root, old text, new text, golden)
`old` must occur in the file (it is replaced everywhere it occurs, which is what
a deliberate one-line fault looks like in these files); `golden` adds the
golden_test target to the run for visual faults.

  python3 -I mutants.py count      -> number of mutants
  python3 -I mutants.py apply N    -> applies mutant N, prints "name|golden";
                                      exit 3 when `old` is not in the file
"""
import sys

L = 'utility/mc_ds_charts/lib/src/'
MATH = L + 'chart_math.dart'
BAR = L + 'mc_bar_chart.dart'
DON = L + 'mc_donut_chart.dart'
LIN = L + 'mc_line_chart.dart'
RAD = L + 'mc_radar_chart.dart'
TIM = L + 'mc_timeline.dart'
ROLE = L + 'chart_role.dart'
VAL = L + 'chart_validation.dart'
COM = L + 'chart_common.dart'
TOK = 'utility/mc_ds_tokens/lib/src/colors.dart'

M = [
    # --- nice ticks ---------------------------------------------------------
    ('tick: 1 step becomes 2', MATH, '      ? 1\n      : f <= 2', '      ? 2\n      : f <= 2', False),
    ('tick: 2 step becomes 3', MATH, '      ? 2\n      : f <= 5', '      ? 3\n      : f <= 5', False),
    ('tick: 5 step becomes 4', MATH, '      ? 5\n      : 10;', '      ? 4\n      : 10;', False),
    ('tick: 10 step becomes 8', MATH, '      : 10;\n  return nice', '      : 8;\n  return nice', False),
    ('tick: raw step ignores the minus one', MATH, '(hi - lo) / (targetTicks - 1)', '(hi - lo) / targetTicks', False),
    ('tick: first tick rounds instead of flooring', MATH, '.floorToDouble() * step', '.roundToDouble() * step', False),
    ('tick: last tick floors instead of ceiling', MATH, '.ceilToDouble() * step', '.floorToDouble() * step', False),
    ('tick: zero not included for bars', MATH, 'var lo = includeZero ? math.min(dataMin, 0.0) : dataMin;', 'var lo = dataMin;', False),
    ('tick: zero range gets 2', MATH, '      hi = 1;', '      hi = 2;', False),
    ('tick: single value not padded', MATH, 'final pad = lo.abs() / 2;', 'final pad = 0.0;', False),
    ('tick: reversed bounds accepted', MATH, 'if (dataMin > dataMax) {', 'if (false) {', False),
    ('tick: count off by one', MATH, 'int get count => (span / step).round() + 1;', 'int get count => (span / step).round() + 2;', False),
    ('tick: floating-point noise kept', MATH, 'double _clean(double v) => double.parse(v.toStringAsPrecision(12));', 'double _clean(double v) => v;', False),
    ('tick: fraction inverted', MATH, '(value - min) / span', '(max - value) / span', False),
    ('tick: negative zero printed', MATH, 'final v = value == 0 ? 0.0 : value;', 'final v = value;', False),
    # --- bar geometry -------------------------------------------------------
    ('bar: zero line pinned to the bottom', MATH, '  final zero = along(0);', '  final zero = vertical ? plot.bottom : plot.left;', False),
    ('bar: extents not ordered', MATH, 'math.min(end, zero)', 'math.max(end, zero)', False),
    ('bar: progress ignored', MATH, '(along(values[i]) - zero) * progress', '(along(values[i]) - zero)', False),
    ('bar: gap ignored', MATH, 'slot * (1 - gapFraction)', 'slot', False),
    ('bar: minimum thickness dropped', MATH, 'math.max(1.0, slot * (1 - gapFraction))', 'slot * (1 - gapFraction)', False),
    ('bar: value axis not inverted', MATH, 'plot.bottom - scale.fraction(v) * plot.height', 'plot.top + scale.fraction(v) * plot.height', False),
    ('bar: tick positions all on zero', MATH, '[for (final t in scale.ticks) along(t)]', '[for (final t in scale.ticks) along(0)]', False),
    # --- donut sweeps -------------------------------------------------------
    ('sweep: minimum sweep never applied', MATH, 'if (values[i] / freeTotal * available < minSweep) {', 'if (false) {', False),
    ('sweep: pinned share not deducted', MATH, 'final available = full - pinned.length * minSweep;', 'final available = full;', False),
    ('sweep: pinned segment gets half the minimum', MATH, '? minSweep\n            : values[i]', '? minSweep / 2\n            : values[i]', False),
    ('sweep: no repeat after pinning', MATH, '    if (!changed) {', '    if (true) {', False),
    ('sweep: zero values counted as positive', MATH, 'if (values[i] > 0) i,', 'if (values[i] >= 0) i,', False),
    ('sweep: equal share fallback removed', MATH, 'if (positive.length * minSweep >= full) {', 'if (false) {', False),
    ('arcs: start not at 12 oclock', MATH, 'double startAngle = -math.pi / 2,', 'double startAngle = 0,', False),
    ('arcs: starts advance by half a sweep', MATH, '    at += s;', '    at += s / 2;', False),
    # --- radar vertices -----------------------------------------------------
    ('radar: axes run anticlockwise', MATH, '-math.pi / 2 + index * 2 * math.pi / count', '-math.pi / 2 - index * 2 * math.pi / count', False),
    ('radar: value not clamped', MATH, 'radius * value.clamp(0.0, 1.0)', 'radius * value', False),
    ('radar: angle step uses count plus one', MATH, 'index * 2 * math.pi / count;', 'index * 2 * math.pi / (count + 1);', False),
    ('radar: cos and sin swapped', MATH, 'center.dx + r * math.cos(angle)', 'center.dx + r * math.sin(angle)', False),
    # --- label helpers ------------------------------------------------------
    ('stride: floors instead of ceiling', MATH, '(labelWidth / slotWidth).ceil()', '(labelWidth / slotWidth).floor()', False),
    ('slot centre: half slot dropped', MATH, 'left + (index + 0.5) *', 'left + (index + 0.0) *', False),
    # --- bar painter --------------------------------------------------------
    ('bar painter: zero line as thin as the grid', BAR, 'static const double zeroLineWidth = 1.5;', 'static const double zeroLineWidth = 1;', False),
    ('bar painter: zero line off its coordinate', BAR, 'vertical ? Offset(plot.left, g.zero) : Offset(g.zero, plot.top),', 'vertical ? Offset(plot.left, g.zero + 2) : Offset(g.zero, plot.top),', True),
    ('bar painter: zero tick gets a grid line', BAR, 'if (ticks[i] != 0) {', 'if (true) {', False),
    ('bar painter: zero-extent bars drawn', BAR, 'if (r.width > 0 && r.height > 0) {', 'if (true) {', False),
    ('bar painter: highlight on the first bar', BAR, 'g.bars[h].inflate(1)', 'g.bars[0].inflate(1)', True),
    ('bar painter: highlight bound off by one', BAR, 'h < data.length) {', 'h <= data.length) {', False),
    ('bar painter: default role is series2', BAR, '(data[i].role ?? McChartRole.series1)', '(data[i].role ?? McChartRole.series2)', True),
    ('bar painter: semantics drop the value', BAR, "label: '${data[i].label}: ${valueFormatter(data[i].value)}',", "label: data[i].label,", False),
    ('bar painter: semantics order reversed', BAR, 'OrdinalSortKey(i.toDouble())', 'OrdinalSortKey((data.length - i).toDouble())', False),
    ('bar chart: NaN guard removed', BAR, '(d) => d.isFinite,', '(d) => true,', False),
    ('bar painter: labels pushed back inside the canvas', BAR, 'if (left < 0 || left + tp.width > size.width) {', 'if (false) {', False),
    # --- donut painter ------------------------------------------------------
    ('donut painter: gap not applied', DON, '? McArc(arc.start + gap / 2, arc.sweep - gap)', '? arc', False),
    ('donut painter: gap on a single segment', DON, 'positiveCount > 1 &&', 'positiveCount > 0 &&', False),
    ('donut chart: negative values accepted', DON, 'value.isFinite && value >= 0', 'value.isFinite', False),
    ('donut painter: semantics order reversed', DON, 'OrdinalSortKey(i.toDouble())', 'OrdinalSortKey((data.length - i).toDouble())', False),
    ('donut painter: no track while drawing in', DON, 'positive == 0 || _progress.value < 1', 'positive == 0', False),
    ('donut painter: ring thinner than designed', DON, 'static const double thicknessFraction = 0.28;', 'static const double thicknessFraction = 0.1;', True),
    # --- line painter -------------------------------------------------------
    ('line: gap drawn as a point', LIN, '      values[i].isFinite\n          ?', '      true\n          ?', False),
    ('line: zero line always drawn', LIN, 'if (l.scale.min <= 0 && l.scale.max >= 0) {', 'if (true) {', False),
    ('line: every series in the first colour', LIN, '(series[i].role ?? McChartRole.forIndex(i))', '(series[i].role ?? McChartRole.series1)', False),
    ('line: semantics skip nothing', LIN, 'if (series[s].values[i].isFinite)', 'if (true)', False),
    # --- radar painter ------------------------------------------------------
    ('radar: non-finite value not zeroed', RAD, '(i < values.length && values[i].isFinite ? values[i] : 0)', '(i < values.length ? values[i] : 0)', False),
    ('radar: opaque fill', RAD, 'color.withValues(alpha: 0.2)', 'color.withValues(alpha: 1.0)', True),
    ('radar: series colour index', RAD, '(series[i].role ?? McChartRole.forIndex(i))', '(series[i].role ?? McChartRole.series1)', False),
    # --- timeline -----------------------------------------------------------
    ('timeline: first line starts at the top', TIM, 'Offset(x, isFirst ? markerY : 0)', 'Offset(x, 0)', False),
    ('timeline: last line runs to the bottom', TIM, 'isLast ? markerY : size.height', 'size.height', False),
    ('timeline: single event draws a line', TIM, 'if (!(isFirst && isLast)) {', 'if (true) {', False),
    ('timeline: last flag off by one', TIM, 'isLast: i == events.length - 1,', 'isLast: i == events.length,', False),
    ('timeline: semantics order of date and title', TIM, '[date, title, if (description != null) description]', '[title, date, if (description != null) description]', False),
    # --- colour roles -------------------------------------------------------
    ('role: positive resolves to negative', ROLE, 'McChartRole.positive => palette.positive,', 'McChartRole.positive => palette.negative,', False),
    ('role: series3 resolves to series2', ROLE, 'McChartRole.series3 => palette.series3,', 'McChartRole.series3 => palette.series2,', False),
    ('role: neutral resolves to series1', ROLE, 'McChartRole.neutral => palette.neutral,', 'McChartRole.neutral => palette.series1,', False),
    ('role: cycle repeats series3', ROLE, 'McChartRole.series3,\n    McChartRole.neutral,\n  ];', 'McChartRole.series3,\n    McChartRole.series3,\n  ];', False),
    ('palette: dark series2 too dark for 3:1', TOK, 'series2: Color(0xFF6CA8FF)', 'series2: Color(0xFF223A5F)', False),
    ('palette: high-contrast series3 too light', TOK, 'series3: Color(0xFF00574F)', 'series3: Color(0xFF99D6D0)', False),
    ('palette: neutral alias too faint', TOK, 'Color get neutral => outline;', 'Color get neutral => surfaceVariant;', False),
    ('palette: positive alias is the error colour', TOK, 'Color get positive => success;', 'Color get positive => error;', False),
    ('palette: lerp drops series1', TOK, 'series1: c(a.series1, b.series1),', 'series1: a.series1,', False),
    ('palette: equality ignores series3', TOK, 'series2,\n    series3,\n  ];', 'series2,\n  ];', False),
    # --- validation ---------------------------------------------------------
    ('validation: release throws as well', VAL, '    if (!isRelease) {\n      throw ArgumentError(message);\n    }\n    _report(\'$message Skipped.\');', '    if (true) {\n      throw ArgumentError(message);\n    }\n    _report(\'$message Skipped.\');', False),
    ('validation: debug does not throw', VAL, '    if (!isRelease) {\n      throw ArgumentError(message);\n    }\n    _report(\'$message Skipped.\');', '    if (false) {\n      throw ArgumentError(message);\n    }\n    _report(\'$message Skipped.\');', False),
    ('validation: release does not report', VAL, "    _report('$message Skipped.');", '', False),
    ('validation: bad items kept in release', VAL, 'return items.where(isValid).toList(growable: false);', 'return items;', False),
    ('validation: check never reports', VAL, '    _report(message);\n    return false;', '    return false;', False),
    # --- review round -------------------------------------------------------
    ('bar: highlight not mapped past a skipped bar', BAR, '? widget.data.take(h).where((d) => d.isFinite).length', '? h', False),
    ('bar: skipped bar still highlighted', BAR, '(widget.data[h].isFinite\n', '(true\n', False),
    ('bar: highlight change alone ignored', BAR, '        old.highlightIndex != widget.highlightIndex;', '        false;', False),
    ('donut: roles resolved after dropping bad values', DON, 'role: roles[i],', 'role: widget.data[i].role,', False),
    ('donut: more than four default roles allowed', DON, 'given.where((r) => r == null).length <= McChartRole.cycle.length,', 'true,', False),
    ('role: previous neighbour does not wrap', ROLE, 'if (n > 1) out[(i + n - 1) % n],', 'if (i > 0) out[i - 1],', False),
    ('role: next neighbour does not wrap', ROLE, 'if (n > 1) out[(i + 1) % n],', 'if (i + 1 < n) out[i + 1],', False),
    ('role: given roles overwritten', ROLE, '      if (out[i] != null) {\n        continue;\n      }', '      if (false) {\n        continue;\n      }', False),
    ('line: zero line missing when the axis starts at 0', LIN, 'if (l.scale.min <= 0 && l.scale.max >= 0) {', 'if (l.scale.min < 0 && l.scale.max > 0) {', False),
    ('line: data check over the untruncated series', LIN, '        _series.any(', '        w.series.any(', False),
    ('format: negative zero for whole values', MATH, 'return (value == 0 ? 0.0 : value).toStringAsFixed(0);', 'return value.toStringAsFixed(0);', False),
    ('format: negative zero for tiny values', MATH, "return s == '-0' ? '0' : s;", 'return s;', False),
    ('radar: semantics stop at the shorter series', RAD, 'for (var i = 0; i < axes.length; i++) ', 'for (var i = 0; i < math.min(axes.length, series[s].values.length); i++) ', False),
    ('radar: semantics read a missing value as the first', RAD, 'valueFormatter(i < series[s].values.length && series[s].values[i].isFinite', 'valueFormatter(series[s].values.isNotEmpty && series[s].values[0].isFinite', False),
    ('animation: draw-in replays when animation is switched on', COM, '      _controller!.value = 1;', '      _controller!.forward(from: 0);', False),
    ('animation: curved animation not disposed when switched off', COM, '      _curved?.dispose();\n      _controller?.dispose();\n      _controller = null;', '      _controller?.dispose();\n      _controller = null;', False),
    ('animation: curved animation not disposed with the state', COM, '    _curved?.dispose();\n    _controller?.dispose();\n    super.dispose();', '    _controller?.dispose();\n    super.dispose();', False),
    # --- shared helpers -----------------------------------------------------
    ('animation: reduced motion ignored', COM, 'animateChart && !McA11y.reduceMotion(context)', 'animateChart', False),
    ('animation: restarts on every update', COM, 'if (restart) {', 'if (true) {', False),
    ('canvas: summary label dropped', COM, 'label: summary,', "label: '',", False),
    ('equality: NaN differs from NaN', COM, '!(a[i].isNaN && b[i].isNaN)', 'true', False),
]


def main():
    cmd = sys.argv[1]
    if cmd == 'count':
        print(len(M))
        return
    n = int(sys.argv[2])
    name, path, old, new, golden = M[n]
    s = open(path).read()
    if old not in s:
        print(name + '|NOT APPLIED')
        sys.exit(3)
    t = s.replace(old, new)
    if t == s:
        print(name + '|NO CHANGE')
        sys.exit(3)
    open(path, 'w').write(t)
    print(name + '|' + ('golden' if golden else 'plain') + '|' + path)


main()
