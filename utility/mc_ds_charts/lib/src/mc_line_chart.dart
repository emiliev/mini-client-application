import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mc_ds_charts/src/chart_common.dart';
import 'package:mc_ds_charts/src/chart_math.dart';
import 'package:mc_ds_charts/src/chart_role.dart';
import 'package:mc_ds_charts/src/chart_validation.dart';
import 'package:mc_ds_charts/src/mc_bar_chart.dart' show mcTickCountFor;
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One line: a [label] and one value per x label. A NaN or infinite value is
/// a gap (see [McLineChart]). [role] defaults to the series' position.
@immutable
class McLineSeries {
  const McLineSeries({required this.label, required this.values, this.role});

  final String label;
  final List<double> values;
  final McChartRole? role;

  @override
  bool operator ==(Object other) =>
      other is McLineSeries &&
      other.label == label &&
      other.role == role &&
      mcSameDoubles(other.values, values);

  @override
  int get hashCode => Object.hash(label, role, values.length);
}

/// The point of each value of a line series, or null for a gap.
///
/// Slot centres across [plot] (like bars); y from [scale]. [progress] (0..1)
/// lifts the points from the bottom of the plot for the animation.
List<Offset?> mcLayoutLinePoints({
  required Rect plot,
  required List<double> values,
  required McTickScale scale,
  required int count,
  double progress = 1,
}) {
  return [
    for (var i = 0; i < math.min(values.length, count); i++)
      values[i].isFinite
          ? Offset(
              mcSlotCenter(plot.left, plot.right, i, count),
              plot.bottom - scale.fraction(values[i]) * plot.height * progress,
            )
          : null,
  ];
}

/// Paints a [McLineChart]. Public so tests can drive it with a recording
/// canvas; features use [McLineChart].
class McLinePainter extends CustomPainter {
  McLinePainter({
    required this.xLabels,
    required this.series,
    required this.palette,
    required this.labelStyle,
    required this.textScaler,
    required this.valueFormatter,
    Animation<double> progress = kAlwaysCompleteAnimation,
  }) : _progress = progress,
       super(repaint: progress);

  final List<String> xLabels;
  final List<McLineSeries> series;
  final McPalette palette;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final McValueFormatter valueFormatter;
  final Animation<double> _progress;

  static const double lineWidth = 2;
  static const double markerRadius = 4;
  static const double zeroLineWidth = 1.5;
  static const double gridLineWidth = 1;

  Color colorFor(int i) =>
      (series[i].role ?? McChartRole.forIndex(i)).resolve(palette);

  Iterable<double> get _finite => series
      .expand((s) => s.values.take(xLabels.length))
      .where((v) => v.isFinite);

  double get _lineHeight => mcLabelPainter('Ag', labelStyle, textScaler).height;

  ({Rect plot, McTickScale scale}) layout(Size size) {
    final finite = _finite.toList();
    final line = _lineHeight;
    final lo = finite.isEmpty ? 0.0 : finite.reduce(math.min);
    final hi = finite.isEmpty ? 0.0 : finite.reduce(math.max);
    final catH = line + 6;
    final scale = mcNiceTicks(
      lo,
      hi,
      targetTicks: mcTickCountFor(
        math.max(1.0, size.height - catH - line / 2),
        line * 2,
      ),
    );
    final tickW = scale.ticks
        .map(
          (t) => mcLabelPainter(
            mcFormatTick(t, step: scale.step),
            labelStyle,
            textScaler,
          ).width,
        )
        .reduce(math.max);
    return (
      scale: scale,
      plot: Rect.fromLTRB(
        math.min(tickW + 6, size.width / 2),
        line / 2 + markerRadius,
        size.width - markerRadius,
        math.max(line / 2 + markerRadius + 1, size.height - catH),
      ),
    );
  }

  /// The points of series [i] (null for gaps) at the current progress.
  List<Offset?> pointsOf(int i, Size size) {
    final l = layout(size);
    return mcLayoutLinePoints(
      plot: l.plot,
      values: series[i].values,
      scale: l.scale,
      count: xLabels.length,
      progress: _progress.value,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (xLabels.isEmpty || series.isEmpty) {
      return;
    }
    final l = layout(size);
    final plot = l.plot;
    final ticks = l.scale.ticks;
    final grid = Paint()
      ..color = palette.outline.withValues(alpha: 0.4)
      ..strokeWidth = gridLineWidth
      ..style = PaintingStyle.stroke;
    final muted = labelStyle.copyWith(color: palette.onSurfaceMuted);
    for (final t in ticks) {
      final y = plot.bottom - l.scale.fraction(t) * plot.height;
      if (t != 0) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      }
      final tp = mcLabelPainter(
        mcFormatTick(t, step: l.scale.step),
        muted,
        textScaler,
      );
      tp.paint(canvas, Offset(plot.left - 6 - tp.width, y - tp.height / 2));
    }
    if (l.scale.min < 0 && l.scale.max > 0) {
      final y = plot.bottom - l.scale.fraction(0) * plot.height;
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = palette.onSurfaceMuted
          ..strokeWidth = zeroLineWidth
          ..style = PaintingStyle.stroke,
      );
    }

    // x labels
    final n = xLabels.length;
    final slot = plot.width / n;
    final cap = textScaler.scale(labelStyle.fontSize ?? 12) * 5;
    final natural = xLabels
        .map((s) => mcLabelPainter(s, labelStyle, textScaler).width)
        .reduce(math.max);
    final stride = mcLabelStride(math.min(natural, cap) + 8, slot);
    final style = labelStyle.copyWith(color: palette.onSurface);
    for (var i = 0; i < n; i += stride) {
      final tp = mcLabelPainter(
        xLabels[i],
        style,
        textScaler,
        maxWidth: math.max(1, slot * stride - 8),
      );
      final cx = mcSlotCenter(plot.left, plot.right, i, n);
      final left = cx - tp.width / 2;
      if (left < 0 || left + tp.width > size.width) {
        continue; // would be cut off or pushed onto its neighbour
      }
      tp.paint(canvas, Offset(left, plot.bottom + 6));
    }

    // lines, then markers on top
    for (var s = 0; s < series.length; s++) {
      final points = pointsOf(s, size);
      final color = colorFor(s);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      Path? run;
      var runLength = 0;
      void flush() {
        if (run != null && runLength > 1) {
          canvas.drawPath(run!, stroke);
        }
        run = null;
        runLength = 0;
      }

      for (final p in points) {
        if (p == null) {
          flush();
          continue;
        }
        if (run == null) {
          run = Path()..moveTo(p.dx, p.dy);
        } else {
          run!.lineTo(p.dx, p.dy);
        }
        runLength++;
      }
      flush();
      final fill = Paint()..color = color;
      for (final p in points) {
        if (p != null) {
          _marker(canvas, s, p, fill);
        }
      }
    }
  }

  /// Series 1 draws circles, series 2 squares and series 3 triangles, so the
  /// lines differ by shape as well as by colour.
  void _marker(Canvas canvas, int s, Offset p, Paint fill) {
    switch (s % 3) {
      case 0:
        canvas.drawCircle(p, markerRadius, fill);
      case 1:
        canvas.drawRect(
          Rect.fromCenter(
            center: p,
            width: markerRadius * 2,
            height: markerRadius * 2,
          ),
          fill,
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - markerRadius - 1)
            ..lineTo(p.dx + markerRadius + 1, p.dy + markerRadius)
            ..lineTo(p.dx - markerRadius - 1, p.dy + markerRadius)
            ..close(),
          fill,
        );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    if (xLabels.isEmpty || series.isEmpty) {
      return const [];
    }
    final plot = layout(size).plot;
    return [
      for (var s = 0; s < series.length; s++)
        CustomPainterSemantics(
          key: ValueKey(s),
          rect: Rect.fromLTRB(
            plot.left,
            plot.top + s * plot.height / series.length,
            plot.right,
            plot.top + (s + 1) * plot.height / series.length,
          ),
          properties: SemanticsProperties(
            label:
                '${series[s].label}: ${[
                  for (var i = 0; i < math.min(series[s].values.length, xLabels.length); i++)
                    if (series[s].values[i].isFinite) '${xLabels[i]} ${valueFormatter(series[s].values[i])}',
                ].join(', ')}',
            textDirection: TextDirection.ltr,
            sortKey: OrdinalSortKey(s.toDouble()),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(McLinePainter old) =>
      !listEquals(old.xLabels, xLabels) ||
      !listEquals(old.series, series) ||
      old.palette != palette ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old._progress != _progress;

  @override
  bool shouldRebuildSemantics(McLinePainter old) =>
      !listEquals(old.xLabels, xLabels) ||
      !listEquals(old.series, series) ||
      old.valueFormatter != valueFormatter;
}

/// A line chart of one to three series over shared x labels.
///
/// - Every series has one value per x label (fewer is fine, more is ignored);
///   the y axis is fitted to the data on 1-2-5 ticks and does not have to
///   include zero.
/// - A NaN or infinite value is an [ArgumentError] in debug; in release it is
///   drawn as a gap in the line and reported once.
/// - Series differ by colour role, marker shape (circle, square, triangle) and
///   legend entry. More than three series, or none, is an [ArgumentError] in
///   debug.
/// - Each series is one semantics node reading its x labels and values;
///   [semanticLabel] summarises the chart.
/// - Empty data (no labels, no series or no finite value) shows a
///   [McEmptyView].
class McLineChart extends StatefulWidget {
  const McLineChart({
    required this.xLabels,
    required this.series,
    required this.semanticLabel,
    required this.emptyMessage,
    this.emptyTitle,
    this.valueFormatter = mcFormatValue,
    this.height = 240,
    this.animate = false,
    super.key,
  });

  final List<String> xLabels;
  final List<McLineSeries> series;
  final String semanticLabel;
  final String emptyMessage;
  final String? emptyTitle;
  final McValueFormatter valueFormatter;
  final double height;
  final bool animate;

  @override
  State<McLineChart> createState() => _McLineChartState();
}

class _McLineChartState extends State<McLineChart>
    with TickerProviderStateMixin<McLineChart>, McChartAnimation<McLineChart> {
  bool _hasData = false;
  late List<McLineSeries> _series;

  @override
  bool get animateChart => widget.animate;

  void _validate() {
    final w = widget;
    McChartValidation.check(
      w.series.length <= 3,
      'McLineChart: ${w.series.length} series, at most 3 are supported.',
    );
    McChartValidation.check(
      w.series.every((s) => s.values.length <= w.xLabels.length),
      'McLineChart: a series has more values than x labels.',
    );
    McChartValidation.check(
      w.series.every((s) => s.values.every((v) => v.isFinite)),
      'McLineChart: a value is NaN or infinite; it is drawn as a gap.',
    );
    _series = w.series.length > 3 ? w.series.sublist(0, 3) : w.series;
    _hasData =
        w.xLabels.isNotEmpty &&
        w.series.any(
          (s) => s.values.take(w.xLabels.length).any((v) => v.isFinite),
        );
  }

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void didUpdateWidget(McLineChart old) {
    super.didUpdateWidget(old);
    final changed =
        !listEquals(old.series, widget.series) ||
        !listEquals(old.xLabels, widget.xLabels);
    if (changed) {
      _validate();
    }
    syncChartAnimation(restart: changed);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      return McEmptyView(
        message: widget.emptyMessage,
        title: widget.emptyTitle ?? 'Nothing here yet',
      );
    }
    final palette = context.mcPalette;
    final painter = McLinePainter(
      xLabels: widget.xLabels,
      series: _series,
      palette: palette,
      labelStyle: Theme.of(context).textTheme.bodySmall!,
      textScaler: MediaQuery.textScalerOf(context),
      valueFormatter: widget.valueFormatter,
      progress: progress,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McChartCanvas(
          painter: painter,
          summary: widget.semanticLabel,
          height: widget.height,
        ),
        if (painter.series.length > 1) ...[
          const McGap.md(),
          McChartLegend(
            entries: [
              for (var i = 0; i < painter.series.length; i++)
                McLegendEntry(painter.series[i].label, painter.colorFor(i)),
            ],
          ),
        ],
      ],
    );
  }
}
