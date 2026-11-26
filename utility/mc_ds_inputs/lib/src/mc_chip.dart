import 'package:flutter/material.dart';
import 'package:mc_ds_inputs/src/field_style.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A filter or choice chip with a selected state.
///
/// It is controlled: the owner holds [selected] and reacts to [onSelected]
/// with the new value. A null [onSelected] disables the chip.
///
/// **Size.** The tap target is at least 44 pt tall and wide; the drawn pill is
/// 36 pt tall at 1x and grows with the text scale. The label is one line and
/// ellipsises when the chip is narrower than it (so it never overflows, even
/// at 3x). A selected chip also shows a check mark, so the state is not told
/// by colour alone.
///
/// **Semantics.** One node: the label, a button, with the `selected` flag.
/// [exclusive] adds the mutually-exclusive-group flag (`McChipGroup.single`
/// sets it).
class McChip extends StatelessWidget {
  const McChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.exclusive = false,
    super.key,
  });

  final String label;
  final bool selected;

  /// Called with the value the chip would take (`!selected`); null disables.
  final ValueChanged<bool>? onSelected;

  /// An optional leading icon (hidden while the check mark shows).
  final IconData? icon;

  /// True when the chip belongs to a single-select group.
  final bool exclusive;

  /// The smallest tap target.
  static const double minTarget = mcMinTapTarget;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final enabled = onSelected != null;
    // A disabled selected control is filled with the muted colour, so its
    // text is the "on primary" colour, not the muted one.
    final foreground = selected
        ? p.onPrimary
        : (enabled ? p.onSurface : p.onSurfaceMuted);
    final fill = selected
        ? (enabled ? p.primary : p.onSurfaceMuted)
        : p.surface;
    final outline = !enabled
        ? mcDisabledOutline(context)
        : selected
        ? p.primary
        : p.outline;
    final leading = selected ? Icons.check : icon;
    final shape = StadiumBorder(side: BorderSide(color: outline));
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        enabled: enabled,
        inMutuallyExclusiveGroup: exclusive ? true : null,
        onTap: enabled ? () => onSelected!(!selected) : null,
        excludeSemantics: true,
        // The whole 44 pt box takes the tap; only the drawn pill ripples.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onSelected!(!selected) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: mcMinTapTarget,
              minHeight: mcMinTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: McSpacing.xs),
              child: Ink(
                decoration: ShapeDecoration(color: fill, shape: shape),
                child: InkWell(
                  onTap: enabled ? () => onSelected!(!selected) : null,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: McSpacing.md,
                      vertical: McSpacing.sm,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (leading != null) ...[
                            Icon(
                              leading,
                              size: MediaQuery.textScalerOf(context).scale(18),
                              color: foreground,
                            ),
                            const SizedBox(width: McSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: McTypeScale.label.copyWith(
                                color: foreground,
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
          ),
        ),
      ),
    );
  }
}
