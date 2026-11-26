import 'package:flutter/material.dart';
import 'package:mc_ds_forms/src/mc_form_scope.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// A titled section of a form: a header, an optional description and the
/// fields, spaced evenly. The title is a semantics header, so a screen
/// reader user can jump between groups.
class McFieldGroup extends StatelessWidget {
  const McFieldGroup({
    required this.title,
    required this.children,
    this.description,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  /// False disables every `McFormTextField` in the group (for example while
  /// the form submits).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    return McFormScope.narrow(
      context,
      enabled: enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: McTypeScale.headline.copyWith(color: p.onSurface),
            ),
          ),
          if (description != null) ...[
            const McGap.xs(),
            Text(
              description!,
              style: McTypeScale.caption.copyWith(color: p.onSurfaceMuted),
            ),
          ],
          for (final child in children) ...[const McGap.md(), child],
        ],
      ),
    );
  }
}
