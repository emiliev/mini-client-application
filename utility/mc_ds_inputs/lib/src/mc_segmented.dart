import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mc_ds_inputs/src/field_style.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// One segment of a [McSegmented].
@immutable
class McSegment {
  const McSegment({required this.label, this.icon, this.key});

  final String label;
  final IconData? icon;

  /// Key of this segment, for tests.
  final Key? key;
}

/// A segmented control of two to five segments, exactly one selected. It is
/// controlled: the owner holds [selectedIndex] and reacts to [onChanged] with
/// the tapped index (also when it is the selected one). A null [onChanged]
/// disables the control.
///
/// **Size.** Each segment is at least 44 pt tall and wide. With a bounded
/// width the segments share it equally; with an unbounded one each is as wide
/// as its label. A label wraps to at most two lines and ellipsises after
/// that, and its text scale is capped at [labelMaxScale], so five German
/// labels still fit a phone at 2x and 3x without overflowing.
///
/// **Semantics.** Each segment is a button with the `selected` flag, in a
/// mutually exclusive group.
class McSegmented extends StatelessWidget {
  const McSegmented({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  }) : assert(
         segments.length >= 2 && segments.length <= 5,
         'a segmented control has 2 to 5 segments',
       ),
       assert(
         selectedIndex >= 0 && selectedIndex < segments.length,
         'selectedIndex must be a valid segment index',
       );

  final List<McSegment> segments;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  /// Cap of the label text scale.
  static const double labelMaxScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final enabled = onChanged != null;
    final outline = enabled ? p.outline : mcDisabledOutline(context);
    // The Material sits inside the outline so that the selected segment's
    // ink (painted on it) is not hidden under the control's own fill; the
    // outline is drawn over everything.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: McRadius.mdAll,
        border: Border.all(color: outline),
      ),
      child: Material(
        color: p.surface,
        borderRadius: McRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: _SegmentRow(
          dividerColor: outline,
          children: [
            for (var i = 0; i < segments.length; i++) _segment(context, i),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, int i) {
    final p = context.mcPalette;
    final enabled = onChanged != null;
    final selected = i == selectedIndex;
    final segment = segments[i];
    // A disabled selected control is filled with the muted colour, so its
    // text is the "on primary" colour, not the muted one.
    final foreground = selected
        ? p.onPrimary
        : (enabled ? p.onSurface : p.onSurfaceMuted);
    final fill = selected
        ? (enabled ? p.primary : p.onSurfaceMuted)
        : p.surface;
    return Semantics(
      label: segment.label,
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      onTap: enabled ? () => onChanged!(i) : null,
      excludeSemantics: true,
      child: Ink(
        color: fill,
        child: InkWell(
          key: segment.key,
          onTap: enabled ? () => onChanged!(i) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: mcMinTapTarget,
              minHeight: mcMinTapTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: segments.length > 3 ? McSpacing.xs : McSpacing.md,
                vertical: McSpacing.sm,
              ),
              child: Center(
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (segment.icon != null) ...[
                      Icon(
                        segment.icon,
                        size: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: labelMaxScale)
                            .scale(18),
                        color: foreground,
                      ),
                      const SizedBox(width: McSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        segment.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: labelMaxScale),
                        style: McTypeScale.label.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of segments separated by 1 pt dividers. With a bounded width the
/// segments share it equally; with an unbounded one each is as wide as its
/// content. All are as high as the tallest. Unlike `Row` + `Expanded` +
/// `LayoutBuilder` it answers intrinsic queries (`IntrinsicWidth`,
/// `IntrinsicHeight`, `AlertDialog`).
class _SegmentRow extends MultiChildRenderObjectWidget {
  const _SegmentRow({required this.dividerColor, required super.children});

  final Color dividerColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSegmentRow(dividerColor);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSegmentRow renderObject,
  ) {
    renderObject.dividerColor = dividerColor;
  }
}

class _SegmentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSegmentRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SegmentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SegmentParentData> {
  _RenderSegmentRow(this._dividerColor);

  Color _dividerColor;
  set dividerColor(Color v) {
    if (v != _dividerColor) {
      _dividerColor = v;
      markNeedsPaint();
    }
  }

  static const double _gap = 1;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SegmentParentData) {
      child.parentData = _SegmentParentData();
    }
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    for (var c = firstChild; c != null; c = childAfter(c)) {
      out.add(c);
    }
    return out;
  }

  double _equalWidth(double total, int n) => (total - _gap * (n - 1)) / n;

  /// Every segment as wide as the widest: what an `IntrinsicWidth` needs.
  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final kids = _kids;
    var widest = 0.0;
    for (final c in kids) {
      widest = math.max(widest, c.getMaxIntrinsicWidth(height));
    }
    return widest * kids.length + _gap * (kids.length - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final kids = _kids;
    final each = width.isFinite ? _equalWidth(width, kids.length) : null;
    var h = 0.0;
    for (final c in kids) {
      h = math.max(
        h,
        each == null
            ? c.getMaxIntrinsicHeight(double.infinity)
            : c.getMaxIntrinsicHeight(each),
      );
    }
    return h;
  }

  Size _layout(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    required bool position,
  }) {
    final kids = _kids;
    final n = kids.length;
    final loose = BoxConstraints(maxHeight: constraints.maxHeight);
    final widths = <double>[];
    if (constraints.hasBoundedWidth) {
      widths.addAll(List.filled(n, _equalWidth(constraints.maxWidth, n)));
    } else {
      for (final c in kids) {
        widths.add(layoutChild(c, loose).width);
      }
    }
    // The height comes from intrinsics: a first layout under a loose height
    // would let a centred label take all of it.
    var height = 0.0;
    for (var i = 0; i < n; i++) {
      height = math.max(height, kids[i].getMaxIntrinsicHeight(widths[i]));
    }
    height = constraints.constrainHeight(height);
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      layoutChild(
        kids[i],
        BoxConstraints.tightFor(width: widths[i], height: height),
      );
      if (position) {
        (kids[i].parentData! as _SegmentParentData).offset = Offset(x, 0);
      }
      x += widths[i] + _gap;
    }
    return constraints.constrain(Size(x - _gap, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, ChildLayoutHelper.dryLayoutChild, position: false);

  @override
  void performLayout() {
    size = _layout(constraints, ChildLayoutHelper.layoutChild, position: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    final paint = Paint()..color = _dividerColor;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (c != firstChild) {
        final x = (c.parentData! as _SegmentParentData).offset.dx - _gap;
        context.canvas.drawRect(
          Rect.fromLTWH(offset.dx + x, offset.dy, _gap, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
