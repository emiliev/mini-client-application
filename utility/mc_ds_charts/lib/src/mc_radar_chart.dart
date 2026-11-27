import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mc_ds_charts/src/chart_common.dart';
import 'package:mc_ds_charts/src/chart_math.dart';
import 'package:mc_ds_charts/src/chart_role.dart';
import 'package:mc_ds_charts/src/chart_validation.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One radar polygon: a [label] and one value per axis, 0 (centre) to 1 (rim).
/// Values outside 0..1 are clamped; a NaN or infinite value is drawn as 0 (and
/// is an [ArgumentError] in debug).
@immutable
class McRadarSeries {
  const McRadarSeries({required this.label, required this.values, this.role});

  final String label;
  final List<double> values;
  final McChartRole? role;

  @override
  bool operator ==(Object other) =>
      other is McRadarSeries &&
      other.label == label &&
      other.role == role &&
      mcSameDoubles(other.values, values);

  @override
  int get hashCode => Object.hash(label, role, values.length);
}

/// The polygon of [values] around [center]: one vertex per axis.
List<Offset> mcRadarPolygon({
  required Offset center,
  required double radius,
  required List<double> values,
  required int count,
  double progress = 1,
}) => [
  for (var i = 0; i < count; i++)
    mcRadarVertex(
      center: center,
      radius: radius,
      index: i,
      count: count,
      value:
          (i < values.length && values[i].isFinite ? values[i] : 0) * progress,
    ),
];

/// Paints a [McRadarChart]. Public so tests can drive it with a recording
/// canvas; features use [McRadarChart].
class McRadarPainter extends CustomPainter {
  McRadarPainter({
    required this.axes,
    required this.series,
    required this.palette,
    required this.labelStyle,
    required this.textScaler,
    required this.valueFormatter,
    Animation<double> progress = kAlwaysCompleteAnimation,
  }) : _progress = progress,
       super(repaint: progress);

  final List<String> axes;
  final List<McRadarSeries> series;
  final McPalette palette;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final McValueFormatter valueFormatter;
  final Animation<double> _progress;

  /// The ring levels (fractions of the radius).
  static const List<double> rings = [0.25, 0.5, 0.75, 1];
  static const double seriesLineWidth = 2;
  static const double gridLineWidth = 1;

  Color colorFor(int i) =>
      (series[i].role ?? McChartRole.forIndex(i)).resolve(palette);

  /// The centre and rim radius for [size]; the rim leaves room for the axis
  /// labels.
  ({Offset center, double radius, double labelWidth}) frame(Size size) {
    final line = mcLabelPainter('Ag', labelStyle, textScaler).height;
    final natural = axes.isEmpty
        ? 0.0
        : axes
              .map((a) => mcLabelPainter(a, labelStyle, textScaler).width)
              .reduce(math.max);
    final labelW = math.min(natural, size.width * 0.28);
    final radius = math.max(
      8.0,
      math.min(size.width / 2 - labelW - 6, size.height / 2 - line - 6),
    );
    return (
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
      labelWidth: labelW,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    if (n == 0 || series.isEmpty) {
      return;
    }
    final f = frame(size);
    final grid = Paint()
      ..color = palette.outline.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = gridLineWidth;
    for (final level in rings) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final v = mcRadarVertex(
          center: f.center,
          radius: f.radius,
          index: i,
          count: n,
          value: level,
        );
        i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(
        f.center,
        mcRadarVertex(
          center: f.center,
          radius: f.radius,
          index: i,
          count: n,
          value: 1,
        ),
        grid,
      );
    }
    for (var s = 0; s < series.length; s++) {
      final pts = polygonOf(s, size);
      final color = colorFor(s);
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = seriesLineWidth
          ..strokeJoin = StrokeJoin.round,
      );
      for (final p in pts) {
        canvas.drawCircle(p, 3, Paint()..color = color);
      }
    }
    final style = labelStyle.copyWith(color: palette.onSurface);
    for (var i = 0; i < n; i++) {
      final tp = mcLabelPainter(
        axes[i],
        style,
        textScaler,
        maxWidth: math.max(1, f.labelWidth),
      );
      final at = mcRadarVertex(
        center: f.center,
        radius: f.radius + 6,
        index: i,
        count: n,
        value: 1,
      );
      final angle = -math.pi / 2 + i * 2 * math.pi / n;
      final c = math.cos(angle);
      final sn = math.sin(angle);
      final dx = c > 0.3 ? 0.0 : (c < -0.3 ? -tp.width : -tp.width / 2);
      final dy = sn > 0.3 ? 0.0 : (sn < -0.3 ? -tp.height : -tp.height / 2);
      tp.paint(
        canvas,
        Offset(
          (at.dx + dx).clamp(0.0, math.max(0, size.width - tp.width)),
          (at.dy + dy).clamp(0.0, math.max(0, size.height - tp.height)),
        ),
      );
    }
  }

  /// The vertices of series [s] at the current progress.
  List<Offset> polygonOf(int s, Size size) {
    final f = frame(size);
    return mcRadarPolygon(
      center: f.center,
      radius: f.radius,
      values: series[s].values,
      count: axes.length,
      progress: _progress.value,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    if (axes.isEmpty || series.isEmpty) {
      return const [];
    }
    return [
      for (var s = 0; s < series.length; s++)
        CustomPainterSemantics(
          key: ValueKey(s),
          rect: Offset.zero & size,
          properties: SemanticsProperties(
            label:
                '${series[s].label}: ${[
                  for (var i = 0; i < axes.length; i++) '${axes[i]} ${valueFormatter(i < series[s].values.length && series[s].values[i].isFinite ? series[s].values[i].clamp(0.0, 1.0) : 0)}',
                ].join(', ')}',
            textDirection: TextDirection.ltr,
            sortKey: OrdinalSortKey(s.toDouble()),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(McRadarPainter old) =>
      !listEquals(old.axes, axes) ||
      !listEquals(old.series, series) ||
      old.palette != palette ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old._progress != _progress;

  @override
  bool shouldRebuildSemantics(McRadarPainter old) =>
      !listEquals(old.axes, axes) ||
      !listEquals(old.series, series) ||
      old.valueFormatter != valueFormatter;
}

/// A radar (spider) chart of three to eight axes and one or two series.
///
/// - Values run from 0 at the centre to 1 at the rim and are clamped to that
///   range. Normalise before passing data.
/// - Fewer than 3 or more than 8 axes, more than 2 series, a series whose
///   length differs from the axes, and NaN or infinite values are an
///   [ArgumentError] in debug; in release they are drawn as well as they can
///   be (a non-finite value as 0) and reported once.
/// - Each series is one semantics node reading axis names and values;
///   [semanticLabel] summarises the chart.
/// - No axes or no series shows a [McEmptyView].
class McRadarChart extends StatefulWidget {
  const McRadarChart({
    required this.axes,
    required this.series,
    required this.semanticLabel,
    required this.emptyMessage,
    this.emptyTitle,
    this.valueFormatter = mcFormatValue,
    this.height = 280,
    this.animate = false,
    super.key,
  });

  final List<String> axes;
  final List<McRadarSeries> series;
  final String semanticLabel;
  final String emptyMessage;
  final String? emptyTitle;
  final McValueFormatter valueFormatter;
  final double height;
  final bool animate;

  @override
  State<McRadarChart> createState() => _McRadarChartState();
}

class _McRadarChartState extends State<McRadarChart>
    with
        TickerProviderStateMixin<McRadarChart>,
        McChartAnimation<McRadarChart> {
  late List<McRadarSeries> _series;

  @override
  bool get animateChart => widget.animate;

  void _validate() {
    final w = widget;
    McChartValidation.check(
      w.axes.isEmpty || (w.axes.length >= 3 && w.axes.length <= 8),
      'McRadarChart: ${w.axes.length} axes, 3 to 8 are supported.',
    );
    McChartValidation.check(
      w.series.length <= 2,
      'McRadarChart: ${w.series.length} series, at most 2 are supported.',
    );
    McChartValidation.check(
      w.series.every((s) => s.values.length == w.axes.length),
      'McRadarChart: a series needs one value per axis.',
    );
    McChartValidation.check(
      w.series.every((s) => s.values.every((v) => v.isFinite)),
      'McRadarChart: a value is NaN or infinite; it is drawn as 0.',
    );
    _series = w.series.length > 2 ? w.series.sublist(0, 2) : w.series;
  }

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void didUpdateWidget(McRadarChart old) {
    super.didUpdateWidget(old);
    final changed =
        !listEquals(old.axes, widget.axes) ||
        !listEquals(old.series, widget.series);
    if (changed) {
      _validate();
    }
    syncChartAnimation(restart: changed);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.axes.isEmpty || _series.isEmpty) {
      return McEmptyView(
        message: widget.emptyMessage,
        title: widget.emptyTitle ?? 'Nothing here yet',
      );
    }
    final painter = McRadarPainter(
      axes: widget.axes,
      series: _series,
      palette: context.mcPalette,
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
        if (_series.length > 1) ...[
          const McGap.md(),
          McChartLegend(
            entries: [
              for (var i = 0; i < _series.length; i++)
                McLegendEntry(_series[i].label, painter.colorFor(i)),
            ],
          ),
        ],
      ],
    );
  }
}
