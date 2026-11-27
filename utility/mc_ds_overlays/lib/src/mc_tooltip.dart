import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A tooltip that shows on long press (touch) and on hover (pointer).
///
/// [message] is both what is drawn and what a screen reader reads as the
/// child's tooltip. The tooltip adds no tap target of its own: [child] is
/// the target, and it must already be at least 44 pt.
class McTooltip extends StatelessWidget {
  const McTooltip({required this.message, required this.child, super.key});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: McSpacing.md,
        vertical: McSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.onSurface,
        borderRadius: McRadius.mdAll,
      ),
      textStyle: McTypeScale.caption.copyWith(color: p.surface),
      child: child,
    );
  }
}
