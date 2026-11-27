import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mc_ds_charts/src/chart_role.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One timeline event: a [date] label (already formatted by the caller), a
/// [title], an optional [description] and a marker colour [role].
@immutable
class McTimelineEvent {
  const McTimelineEvent({
    required this.date,
    required this.title,
    this.description,
    this.role = McChartRole.series1,
  });

  final String date;
  final String title;
  final String? description;
  final McChartRole role;

  /// What a screen reader says for the event.
  String get semanticLabel =>
      [date, title, if (description != null) description].join('. ');

  @override
  bool operator ==(Object other) =>
      other is McTimelineEvent &&
      other.date == date &&
      other.title == title &&
      other.description == description &&
      other.role == role;

  @override
  int get hashCode => Object.hash(date, title, description, role);
}

/// Paints one event's rail: the vertical line and the marker.
///
/// The line runs the full height of the row, except that the first event's
/// starts at its marker and the last event's ends there.
class McTimelineRailPainter extends CustomPainter {
  McTimelineRailPainter({
    required this.markerColor,
    required this.lineColor,
    required this.ringColor,
    required this.markerY,
    required this.isFirst,
    required this.isLast,
  });

  final Color markerColor;
  final Color lineColor;
  final Color ringColor;

  /// The marker's y inside the row.
  final double markerY;
  final bool isFirst;
  final bool isLast;

  static const double lineWidth = 2;
  static const double markerRadius = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    if (!(isFirst && isLast)) {
      canvas.drawLine(
        Offset(x, isFirst ? markerY : 0),
        Offset(x, isLast ? markerY : size.height),
        Paint()
          ..color = lineColor
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(
      Offset(x, markerY),
      markerRadius + 2,
      Paint()..color = ringColor,
    );
    canvas.drawCircle(
      Offset(x, markerY),
      markerRadius,
      Paint()..color = markerColor,
    );
  }

  @override
  bool shouldRepaint(McTimelineRailPainter old) =>
      old.markerColor != markerColor ||
      old.lineColor != lineColor ||
      old.ringColor != ringColor ||
      old.markerY != markerY ||
      old.isFirst != isFirst ||
      old.isLast != isLast;
}

/// A vertical timeline of events in the given order (top to bottom).
///
/// It is not scrollable: put it in the caller's scroll view. [semanticLabel]
/// summarises it; each event is one semantics node reading "date. title.
/// description" in data order. Empty [events] shows a [McEmptyView].
class McTimeline extends StatelessWidget {
  const McTimeline({
    required this.events,
    required this.semanticLabel,
    required this.emptyMessage,
    this.emptyTitle,
    super.key,
  });

  final List<McTimelineEvent> events;
  final String semanticLabel;
  final String emptyMessage;
  final String? emptyTitle;

  /// Width of the rail column.
  static const double railWidth = 28;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return McEmptyView(
        message: emptyMessage,
        title: emptyTitle ?? 'Nothing here yet',
      );
    }
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final markerY = scaler.scale(text.bodySmall!.fontSize ?? 12) * 0.8;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < events.length; i++)
            Semantics(
              container: true,
              label: events[i].semanticLabel,
              sortKey: OrdinalSortKey(i.toDouble()),
              child: ExcludeSemantics(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: railWidth,
                        child: CustomPaint(
                          painter: McTimelineRailPainter(
                            markerColor: events[i].role.resolve(p),
                            lineColor: p.outline,
                            ringColor: p.surface,
                            markerY: markerY,
                            isFirst: i == 0,
                            isLast: i == events.length - 1,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: i == events.length - 1 ? 0 : McSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                events[i].date,
                                style: text.bodySmall,
                              ),
                              const McGap.xs(),
                              Text(events[i].title, style: text.titleMedium),
                              if (events[i].description != null) ...[
                                const McGap.xs(),
                                Text(
                                  events[i].description!,
                                  style: text.bodyMedium!.copyWith(
                                    color: p.onSurfaceMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
