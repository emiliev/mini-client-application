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

/// One donut segment: a [label], a finite non-negative [value] and an optional
/// colour [role] (default: [McChartRole.forIndex] of its position).
@immutable
class McDonutSegment {
  const McDonutSegment({required this.label, required this.value, this.role});

  final String label;
  final double value;
  final McChartRole? role;

  bool get isValid => value.isFinite && value >= 0;

  @override
  bool operator ==(Object other) =>
      other is McDonutSegment &&
      other.label == label &&
      other.role == role &&
      (other.value == value || (other.value.isNaN && value.isNaN));

  @override
  int get hashCode => Object.hash(label, role, value.isNaN ? 0 : value);
}

/// Paints a [McDonutChart]. Public so tests can drive it with a recording
/// canvas; features use [McDonutChart].
class McDonutPainter extends CustomPainter {
  McDonutPainter({
    required this.data,
    required this.palette,
    required this.valueFormatter,
    this.minSweep = mcDonutMinSweep,
    Animation<double> progress = kAlwaysCompleteAnimation,
  }) : _progress = progress,
       super(repaint: progress);

  final List<McDonutSegment> data;
  final McPalette palette;
  final McValueFormatter valueFormatter;

  /// Smallest sweep of a non-zero segment, in radians.
  final double minSweep;
  final Animation<double> _progress;

  /// The empty space left between neighbouring segments (1 degree).
  static const double gap = math.pi / 180;

  /// The ring's stroke is this fraction of its outer radius (at least 12).
  static const double thicknessFraction = 0.28;

  List<double> get sweeps =>
      mcDonutSweeps([for (final d in data) d.value], minSweep: minSweep);

  /// The arcs of every segment (zero sweeps for zero values), scaled by the
  /// animation progress.
  List<McArc> get arcs =>
      mcDonutArcs([for (final s in sweeps) s * _progress.value]);

  McArc _drawn(McArc arc, int positiveCount) =>
      positiveCount > 1 && arc.sweep > 2 * gap
      ? McArc(arc.start + gap / 2, arc.sweep - gap)
      : arc;

  Color colorFor(int i) =>
      (data[i].role ?? McChartRole.forIndex(i)).resolve(palette);

  /// Ring centre, stroke width and the radius of its centre line.
  ({Offset center, double thickness, double radius}) ring(Size size) {
    final outer = math.max(1.0, math.min(size.width, size.height) / 2);
    final thickness = math.min(
      outer,
      math.max(12.0, outer * thicknessFraction),
    );
    return (
      center: Offset(size.width / 2, size.height / 2),
      thickness: thickness,
      radius: outer - thickness / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final r = ring(size);
    final rect = Rect.fromCircle(center: r.center, radius: r.radius);
    final all = arcs;
    final positive = all.where((a) => a.sweep > 0).length;
    // The empty track shows for all-zero data and while the ring draws in.
    if (positive == 0 || _progress.value < 1) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.thickness
          ..strokeCap = StrokeCap.butt
          ..color = palette.surfaceVariant,
      );
    }
    if (positive == 0) {
      return;
    }
    for (var i = 0; i < all.length; i++) {
      if (all[i].sweep <= 0) {
        continue;
      }
      final a = _drawn(all[i], positive);
      canvas.drawArc(
        rect,
        a.start,
        a.sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.thickness
          ..strokeCap = StrokeCap.butt
          ..color = colorFor(i),
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    if (data.isEmpty) {
      return const [];
    }
    final r = ring(size);
    final planned = mcDonutArcs(sweeps);
    return [
      for (var i = 0; i < data.length; i++)
        CustomPainterSemantics(
          key: ValueKey(i),
          rect: Rect.fromCenter(
            center:
                r.center +
                Offset(math.cos(planned[i].mid), math.sin(planned[i].mid)) *
                    r.radius,
            width: r.thickness,
            height: r.thickness,
          ),
          properties: SemanticsProperties(
            label: '${data[i].label}: ${valueFormatter(data[i].value)}',
            textDirection: TextDirection.ltr,
            sortKey: OrdinalSortKey(i.toDouble()),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(McDonutPainter old) =>
      !listEquals(old.data, data) ||
      old.palette != palette ||
      old.minSweep != minSweep ||
      old._progress != _progress;

  @override
  bool shouldRebuildSemantics(McDonutPainter old) =>
      !listEquals(old.data, data) || old.valueFormatter != valueFormatter;
}

/// A donut chart.
///
/// - A non-zero segment never sweeps less than [minSweepDegrees] (default 4):
///   tiny values are raised to it and the others give way in proportion, so
///   the sweeps still add up to 360 degrees (see [mcDonutSweeps]). The drawn
///   arc therefore overstates a tiny value slightly; the legend and the
///   semantics carry the exact numbers.
/// - Values must be finite and not negative: otherwise an [ArgumentError] in
///   debug, and the segment is skipped (and reported once) in release.
/// - Empty data shows a [McEmptyView]; all-zero data shows an empty ring.
/// - [centerLabel] is drawn in the hole; it is hidden from semantics, so
///   [semanticLabel] should say it too.
class McDonutChart extends StatefulWidget {
  const McDonutChart({
    required this.data,
    required this.semanticLabel,
    required this.emptyMessage,
    this.emptyTitle,
    this.centerLabel,
    this.centerCaption,
    this.size = 200,
    this.minSweepDegrees = 4,
    this.showLegend = true,
    this.valueFormatter = mcFormatValue,
    this.animate = false,
    super.key,
  });

  final List<McDonutSegment> data;
  final String semanticLabel;
  final String emptyMessage;
  final String? emptyTitle;
  final String? centerLabel;
  final String? centerCaption;

  /// Diameter, reduced to fit a narrower parent.
  final double size;
  final double minSweepDegrees;
  final bool showLegend;
  final McValueFormatter valueFormatter;
  final bool animate;

  @override
  State<McDonutChart> createState() => _McDonutChartState();
}

class _McDonutChartState extends State<McDonutChart>
    with
        TickerProviderStateMixin<McDonutChart>,
        McChartAnimation<McDonutChart> {
  late List<McDonutSegment> _data;

  @override
  bool get animateChart => widget.animate;

  void _sanitize() {
    final given = [for (final d in widget.data) d.role];
    McChartValidation.check(
      given.where((r) => r == null).length <= McChartRole.cycle.length,
      'McDonutChart: more than ${McChartRole.cycle.length} segments without a '
      'role; name the roles so neighbours stay distinguishable.',
    );
    // Resolve before dropping bad values, so a skipped segment never shifts
    // the colour of the ones after it.
    final roles = McChartRole.resolveAll(given);
    final resolved = [
      for (var i = 0; i < widget.data.length; i++)
        McDonutSegment(
          label: widget.data[i].label,
          value: widget.data[i].value,
          role: roles[i],
        ),
    ];
    _data = McChartValidation.sanitize(
      resolved,
      (d) => d.isValid,
      chart: 'McDonutChart',
      what: 'segment values',
      reason: 'NaN, infinite or negative',
    );
  }

  @override
  void initState() {
    super.initState();
    _sanitize();
  }

  @override
  void didUpdateWidget(McDonutChart old) {
    super.didUpdateWidget(old);
    final changed = !listEquals(old.data, widget.data);
    if (changed) {
      _sanitize();
    }
    syncChartAnimation(restart: changed);
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return McEmptyView(
        message: widget.emptyMessage,
        title: widget.emptyTitle ?? 'Nothing here yet',
      );
    }
    final palette = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final painter = McDonutPainter(
      data: _data,
      palette: palette,
      valueFormatter: widget.valueFormatter,
      minSweep: widget.minSweepDegrees * math.pi / 180,
      progress: progress,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final d = constraints.hasBoundedWidth
            ? math.min(widget.size, constraints.maxWidth)
            : widget.size;
        final ring = painter.ring(Size.square(d));
        final hole = (ring.radius - ring.thickness / 2) * 2 * 0.8;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: d,
              height: d,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  McChartCanvas(
                    painter: painter,
                    summary: widget.semanticLabel,
                    height: d,
                  ),
                  if (widget.centerLabel != null)
                    ExcludeSemantics(
                      child: SizedBox(
                        width: hole,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.centerLabel!,
                                style: text.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              if (widget.centerCaption != null)
                                Text(
                                  widget.centerCaption!,
                                  style: text.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.showLegend) ...[
              const McGap.md(),
              McChartLegend(
                entries: [
                  for (var i = 0; i < _data.length; i++)
                    McLegendEntry(
                      '${_data[i].label} ${widget.valueFormatter(_data[i].value)}',
                      painter.colorFor(i),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
