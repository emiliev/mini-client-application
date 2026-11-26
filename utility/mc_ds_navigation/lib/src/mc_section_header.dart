import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A heading above a block of content, with an optional trailing action
/// ("See all"). The title is a semantics header. The title wraps, so a long
/// one never overflows at large text scales.
class McSectionHeader extends StatelessWidget {
  const McSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction come together',
       );

  final String title;

  /// The trailing action's text; null for none.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final label = actionLabel;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: McSpacing.lg,
        end: McSpacing.sm,
        top: McSpacing.sm,
        bottom: McSpacing.xs,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: mcMinTapTarget),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: McTypeScale.headline.copyWith(color: p.onSurface),
                ),
              ),
            ),
            if (label != null)
              // Loose, at most a third of the free width: a long label
              // ellipsises instead of overflowing, and the title keeps room.
              Flexible(
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: p.primary,
                    minimumSize: const Size(mcMinTapTarget, mcMinTapTarget),
                    textStyle: McTypeScale.label,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
