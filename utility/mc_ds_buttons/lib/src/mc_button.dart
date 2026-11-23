import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

enum McButtonVariant { primary, secondary, tertiary }

/// A text button in one of three emphasis levels. Passing a null [onPressed]
/// disables it. The tap target is at least 44 x 44.
class McButton extends StatelessWidget {
  const McButton({
    required this.label,
    required this.onPressed,
    this.variant = McButtonVariant.primary,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final McButtonVariant variant;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    const shape = RoundedRectangleBorder(borderRadius: McRadius.mdAll);
    const size = Size(mcMinTapTarget, mcMinTapTarget);
    const padding = EdgeInsets.symmetric(
      horizontal: McSpacing.lg,
      vertical: McSpacing.sm,
    );
    final text = Text(label, textAlign: TextAlign.center);

    final Widget button = switch (variant) {
      McButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.onSurfaceMuted,
          minimumSize: size,
          padding: padding,
          shape: shape,
          textStyle: McTypeScale.label,
        ),
        child: text,
      ),
      McButtonVariant.secondary => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.onSurface,
          disabledForegroundColor: p.onSurfaceMuted,
          side: BorderSide(
            color: onPressed == null ? p.surfaceVariant : p.outline,
          ),
          minimumSize: size,
          padding: padding,
          shape: shape,
          textStyle: McTypeScale.label,
        ),
        child: text,
      ),
      McButtonVariant.tertiary => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: p.onSurfaceMuted,
          minimumSize: size,
          padding: padding,
          shape: shape,
          textStyle: McTypeScale.label,
        ),
        child: text,
      ),
    };
    if (!expand) {
      return button;
    }
    // Fill the width only when it is bounded; in a Row or horizontal scroll
    // view an infinite width would throw, so fall back to the natural size.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
