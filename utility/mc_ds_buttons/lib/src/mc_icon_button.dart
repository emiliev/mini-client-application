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
    return Semantics(
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: semanticLabel,
        color: p.onSurface,
        disabledColor: p.onSurfaceMuted,
        constraints: const BoxConstraints(
          minWidth: mcMinTapTarget,
          minHeight: mcMinTapTarget,
        ),
      ),
    );
  }
}
