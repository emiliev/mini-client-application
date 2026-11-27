import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Width used when a chart is laid out with an unbounded width (e.g. in a
/// horizontal scroll view).
const double mcChartUnboundedWidth = 320;

/// Formats a value for semantics and legends.
typedef McValueFormatter = String Function(double value);

/// True when [a] and [b] hold the same numbers, NaN equal to NaN (so a list
/// with a NaN is not seen as "changed" on every rebuild).
bool mcSameDoubles(List<double> a, List<double> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i] && !(a[i].isNaN && b[i].isNaN)) {
      return false;
    }
  }
  return true;
}

/// A one-line label, ellipsised at [maxWidth], laid out and ready to paint.
TextPainter mcLabelPainter(
  String text,
  TextStyle style,
  TextScaler textScaler, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.start,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
}

/// Drives a chart's draw-in animation.
///
/// Off unless the chart asks for it ([animateChart]) and the platform does not
/// ask for reduced motion. [progress] runs 0 to 1 once on first build and again
/// whenever the chart calls [syncChartAnimation] with `restart: true`; without
/// animation it is always 1.
mixin McChartAnimation<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  AnimationController? _controller;
  CurvedAnimation? _curved;
  bool _first = true;

  bool get animateChart;

  Animation<double> get progress => _curved ?? kAlwaysCompleteAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncChartAnimation(restart: _first);
    _first = false;
  }

  void syncChartAnimation({required bool restart}) {
    final on = animateChart && !McA11y.reduceMotion(context);
    if (!on) {
      _curved?.dispose();
      _controller?.dispose();
      _controller = null;
      _curved = null;
      return;
    }
    final created = _controller == null;
    _controller ??= AnimationController(vsync: this, duration: McMotion.slow);
    _curved ??= CurvedAnimation(
      parent: _controller!,
      curve: McMotion.standard,
    );
    if (restart) {
      _controller!.forward(from: 0);
    } else if (created) {
      // Animation switched on later (for example Reduce Motion turned off):
      // show the finished chart, do not replay the draw-in.
      _controller!.value = 1;
    }
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }
}

/// The painted surface of a chart: [painter] on a [height]-tall canvas as wide
/// as the constraints allow, named for assistive technology by [summary].
///
/// The painter's `semanticsBuilder` adds the per-datum nodes as children.
class McChartCanvas extends StatelessWidget {
  const McChartCanvas({
    required this.painter,
    required this.summary,
    required this.height,
    super.key,
  });

  final CustomPainter painter;
  final String summary;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : mcChartUnboundedWidth;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: summary,
          child: CustomPaint(
            size: Size(width, height),
            painter: painter,
          ),
        );
      },
    );
  }
}

/// One legend entry: a colour swatch and a name.
@immutable
class McLegendEntry {
  const McLegendEntry(this.label, this.color);

  final String label;
  final Color color;
}

/// A wrapped legend. Colour is never the only carrier of meaning, so the
/// legend names every series; it is hidden from semantics because the chart's
/// own nodes already read each name.
class McChartLegend extends StatelessWidget {
  const McChartLegend({required this.entries, super.key});

  final List<McLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: context.mcPalette.onSurface,
    );
    final swatch = MediaQuery.textScalerOf(context).scale(10);
    return ExcludeSemantics(
      child: Wrap(
        spacing: McSpacing.md,
        runSpacing: McSpacing.xs,
        children: [
          for (final e in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: swatch,
                  height: swatch,
                  decoration: BoxDecoration(
                    color: e.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const McGap.xs(),
                Flexible(child: Text(e.label, style: text)),
              ],
            ),
        ],
      ),
    );
  }
}
