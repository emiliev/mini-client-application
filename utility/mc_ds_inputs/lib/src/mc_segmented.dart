import 'package:flutter/material.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedWidth;
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
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < segments.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: outline),
                    if (bounded)
                      Expanded(child: _segment(context, i))
                    else
                      _segment(context, i),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
