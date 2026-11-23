import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// An icon-only button. [semanticLabel] is required because there is no
/// visible text; it doubles as the tooltip.
class McIconButton extends StatelessWidget {
  const McIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    // One semantics node carries the label, the button flag and the tap
    // action; the tooltip (sighted hover) and IconButton's own node are
    // excluded so the label is never announced twice or split from the button.
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: p.onSurface,
          disabledColor: p.onSurfaceMuted,
          constraints: const BoxConstraints(
            minWidth: mcMinTapTarget,
            minHeight: mcMinTapTarget,
          ),
        ),
      ),
    );
  }
}
