import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mc_ds_charts/src/chart_common.dart';
import 'package:mc_ds_charts/src/chart_math.dart';
import 'package:mc_ds_charts/src/chart_role.dart';
import 'package:mc_ds_charts/src/chart_validation.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One bar: a [label], a finite [value] (negative values hang below the zero
/// line) and an optional colour [role] (default [McChartRole.series1]).
@immutable
class McBarDatum {
  const McBarDatum({required this.label, required this.value, this.role});

  final String label;
  final double value;
  final McChartRole? role;

  bool get isFinite => value.isFinite;

  @override
  bool operator ==(Object other) =>
      other is McBarDatum &&
      other.label == label &&
      other.role == role &&
      (other.value == value || (other.value.isNaN && value.isNaN));

  @override
  int get hashCode => Object.hash(label, role, value.isNaN ? 0 : value);
}

/// How many ticks fit on an axis [extent] long when each needs [perTick]:
/// at least 3 (so a range is never one coarse step), at most 6.
int mcTickCountFor(double extent, double perTick) =>
    (extent / math.max(perTick, 1)).floor().clamp(3, 6);

/// Everything the bar painter derives from a size.
@immutable
class McBarLayout {
  const McBarLayout({
    required this.plot,
    required this.scale,
    required this.geometry,
    required this.slots,
    required this.categoryWidth,
    required this.categoryHeight,
    required this.axisHeight,
  });

  /// The plotting area (inside the axis and the category labels).
  final Rect plot;
  final McTickScale scale;
  final McBarGeometry geometry;

  /// The full-extent slot of each datum (used for semantics).
  final List<Rect> slots;
  final double categoryWidth;
  final double categoryHeight;
  final double axisHeight;
}

/// Paints a [McBarChart]. Public so tests can drive it with a recording
/// canvas; features use [McBarChart].
class McBarPainter extends CustomPainter {
  McBarPainter({
    required this.data,
    required this.palette,
    required this.labelStyle,
    required this.textScaler,
    required this.vertical,
    required this.valueFormatter,
    this.highlightIndex,
    Animation<double> progress = kAlwaysCompleteAnimation,
  }) : _progress = progress,
       super(repaint: progress);

  final List<McBarDatum> data;
  final McPalette palette;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final bool vertical;
  final McValueFormatter valueFormatter;
  final int? highlightIndex;
  final Animation<double> _progress;

  /// Stroke widths tests use to tell the zero line from the grid.
  static const double zeroLineWidth = 1.5;
  static const double gridLineWidth = 1;
  static const double highlightWidth = 2;

  double get _lineHeight => mcLabelPainter('Ag', labelStyle, textScaler).height;

  double _naturalLabelWidth() => data
      .map((d) => mcLabelPainter(d.label, labelStyle, textScaler).width)
      .reduce(math.max);

  McBarLayout layout(Size size) {
    final values = [for (final d in data) d.value];
    final lo = values.isEmpty ? 0.0 : values.reduce(math.min);
    final hi = values.isEmpty ? 0.0 : values.reduce(math.max);
    final line = _lineHeight;
    final catNatural = data.isEmpty ? 0.0 : _naturalLabelWidth();
    final Rect plot;
    final double catW;
    final double catH;
    final double axisH;
    final McTickScale scale;
    if (vertical) {
      catH = line + 6;
      axisH = 0;
      final estimatePlotH = math.max(1.0, size.height - catH - line / 2);
      scale = mcNiceTicks(
        lo,
        hi,
        includeZero: true,
        targetTicks: mcTickCountFor(estimatePlotH, line * 2),
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
      catW = tickW + 6;
      plot = Rect.fromLTRB(
        math.min(catW, size.width / 2),
        line / 2,
        size.width,
        math.max(line / 2 + 1, size.height - catH),
      );
    } else {
      catH = 0;
      axisH = line + 6;
      catW = math.min(catNatural, size.width * 0.4) + 8;
      final estimatePlotW = math.max(1.0, size.width - catW);
      scale = mcNiceTicks(
        lo,
        hi,
        includeZero: true,
        targetTicks: mcTickCountFor(estimatePlotW, line * 3.5),
      );
      plot = Rect.fromLTRB(
        catW,
        2,
        math.max(catW + 1, size.width - line),
        math.max(3, size.height - axisH),
      );
    }
    final geometry = mcLayoutBars(
      plot: plot,
      values: values,
      scale: scale,
      vertical: vertical,
      progress: _progress.value,
    );
    final n = math.max(data.length, 1);
    final slots = [
      for (var i = 0; i < data.length; i++)
        vertical
            ? Rect.fromLTRB(
                plot.left + i * plot.width / n,
                plot.top,
                plot.left + (i + 1) * plot.width / n,
                size.height,
              )
            : Rect.fromLTRB(
                0,
                plot.top + i * plot.height / n,
                size.width,
                plot.top + (i + 1) * plot.height / n,
              ),
    ];
    return McBarLayout(
      plot: plot,
      scale: scale,
      geometry: geometry,
      slots: slots,
      categoryWidth: catW,
      categoryHeight: catH,
      axisHeight: axisH,
    );
  }

  Color colorFor(int i) =>
      (data[i].role ?? McChartRole.series1).resolve(palette);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final l = layout(size);
    final g = l.geometry;
    final plot = l.plot;
    final grid = Paint()
      ..color = palette.outline.withValues(alpha: 0.4)
      ..strokeWidth = gridLineWidth
      ..style = PaintingStyle.stroke;
    final ticks = l.scale.ticks;

    // 1. grid and value-axis labels
    for (var i = 0; i < ticks.length; i++) {
      final pos = g.tickPositions[i];
      if (ticks[i] != 0) {
        canvas.drawLine(
          vertical ? Offset(plot.left, pos) : Offset(pos, plot.top),
          vertical ? Offset(plot.right, pos) : Offset(pos, plot.bottom),
          grid,
        );
      }
      final tp = mcLabelPainter(
        mcFormatTick(ticks[i], step: l.scale.step),
        labelStyle.copyWith(color: palette.onSurfaceMuted),
        textScaler,
      );
      if (vertical) {
        tp.paint(canvas, Offset(plot.left - 6 - tp.width, pos - tp.height / 2));
      } else {
        tp.paint(
          canvas,
          Offset(
            (pos - tp.width / 2).clamp(0.0, math.max(0, size.width - tp.width)),
            plot.bottom + 6,
          ),
        );
      }
    }

    // 2. bars
    for (var i = 0; i < data.length; i++) {
      final r = g.bars[i];
      if (r.width > 0 && r.height > 0) {
        canvas.drawRect(r, Paint()..color = colorFor(i));
      }
    }

    // 3. the zero line, over the bars
    final zeroPaint = Paint()
      ..color = palette.onSurfaceMuted
      ..strokeWidth = zeroLineWidth
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      vertical ? Offset(plot.left, g.zero) : Offset(g.zero, plot.top),
      vertical ? Offset(plot.right, g.zero) : Offset(g.zero, plot.bottom),
      zeroPaint,
    );

    // 4. the highlighted bar
    final h = highlightIndex;
    if (h != null && h >= 0 && h < data.length) {
      canvas.drawRect(
        g.bars[h].inflate(1),
        Paint()
          ..color = palette.onSurface
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlightWidth,
      );
    }

    // 5. category labels
    final style = labelStyle.copyWith(color: palette.onSurface);
    final n = data.length;
    if (vertical) {
      final slot = plot.width / n;
      final cap = textScaler.scale(labelStyle.fontSize ?? 12) * 5;
      final stride = mcLabelStride(
        math.min(_naturalLabelWidth(), cap) + 8,
        slot,
      );
      for (var i = 0; i < n; i += stride) {
        final tp = mcLabelPainter(
          data[i].label,
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
    } else {
      final slot = plot.height / n;
      for (var i = 0; i < n; i++) {
        final tp = mcLabelPainter(
          data[i].label,
          style,
          textScaler,
          maxWidth: math.max(1, l.categoryWidth - 8),
        );
        tp.paint(
          canvas,
          Offset(
            0,
            plot.top + (i + 0.5) * slot - math.min(tp.height, slot) / 2,
          ),
        );
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    if (data.isEmpty) {
      return const [];
    }
    final l = layout(size);
    return [
      for (var i = 0; i < data.length; i++)
        CustomPainterSemantics(
          key: ValueKey(i),
          rect: l.slots[i],
          properties: SemanticsProperties(
            label: '${data[i].label}: ${valueFormatter(data[i].value)}',
            textDirection: TextDirection.ltr,
            sortKey: OrdinalSortKey(i.toDouble()),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(McBarPainter old) =>
      !listEquals(old.data, data) ||
      old.palette != palette ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.vertical != vertical ||
      old.highlightIndex != highlightIndex ||
      old._progress != _progress;

  @override
  bool shouldRebuildSemantics(McBarPainter old) =>
      !listEquals(old.data, data) || old.valueFormatter != valueFormatter;
}

/// A vertical or horizontal bar chart of one series.
///
/// - Values may be negative: bars hang below (or left of) the zero line.
/// - Colours come from [McChartRole]s per bar; [highlightIndex] outlines one.
/// - [semanticLabel] summarises the chart; every bar is also a semantics node
///   "label: value" in data order. The caller localises both (the design
///   system has no l10n).
/// - NaN and infinite values throw an [ArgumentError] in debug and are skipped
///   (and reported once) in release. Empty data shows a [McEmptyView].
/// - [animate] (default off) grows the bars in; it is ignored under reduced
///   motion.
class McBarChart extends StatefulWidget {
  const McBarChart({
    required this.data,
    required this.semanticLabel,
    required this.emptyMessage,
    this.emptyTitle,
    this.orientation = Axis.vertical,
    this.highlightIndex,
    this.valueFormatter = mcFormatValue,
    this.height = 240,
    this.animate = false,
    super.key,
  });

  final List<McBarDatum> data;
  final String semanticLabel;
  final String emptyMessage;
  final String? emptyTitle;

  /// [Axis.vertical] draws columns; [Axis.horizontal] draws rows (its height
  /// follows the number of bars and ignores [height]).
  final Axis orientation;
  final int? highlightIndex;
  final McValueFormatter valueFormatter;

  /// Height of a vertical chart.
  final double height;
  final bool animate;

  @override
  State<McBarChart> createState() => _McBarChartState();
}

class _McBarChartState extends State<McBarChart>
    with TickerProviderStateMixin<McBarChart>, McChartAnimation<McBarChart> {
  late List<McBarDatum> _data;
  int? _highlight;

  @override
  bool get animateChart => widget.animate;

  void _sanitize() {
    _data = McChartValidation.sanitize(
      widget.data,
      (d) => d.isFinite,
      chart: 'McBarChart',
      what: 'values',
    );
    // The highlight names a position in the caller's list: map it across the
    // skipped values (null when the highlighted bar itself was skipped).
    final h = widget.highlightIndex;
    _highlight = (h == null || h < 0 || h >= widget.data.length)
        ? null
        : (widget.data[h].isFinite
              ? widget.data.take(h).where((d) => d.isFinite).length
              : null);
  }

  @override
  void initState() {
    super.initState();
    _sanitize();
  }

  @override
  void didUpdateWidget(McBarChart old) {
    super.didUpdateWidget(old);
    final changed =
        !listEquals(old.data, widget.data) ||
        old.highlightIndex != widget.highlightIndex;
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
    final scaler = MediaQuery.textScalerOf(context);
    final style = Theme.of(context).textTheme.bodySmall!;
    final vertical = widget.orientation == Axis.vertical;
    final fontSize = style.fontSize ?? 12;
    final height = vertical
        ? widget.height
        : _data.length * math.max(28.0, scaler.scale(fontSize) * 1.8) +
              scaler.scale(fontSize) * 1.35 +
              8;
    return McChartCanvas(
      summary: widget.semanticLabel,
      height: height,
      painter: McBarPainter(
        data: _data,
        palette: palette,
        labelStyle: style,
        textScaler: scaler,
        vertical: vertical,
        valueFormatter: widget.valueFormatter,
        highlightIndex: _highlight,
        progress: progress,
      ),
    );
  }
}
