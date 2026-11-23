import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// A centred error message with a Retry button.
///
/// Strings are parameters with English defaults until `mc_l10n_core` exists.
class McErrorView extends StatelessWidget {
  const McErrorView({
    required this.message,
    required this.onRetry,
    this.title = 'Something went wrong',
    this.retryLabel = 'Retry',
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: McInsets.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One announcement for the whole message; the Retry button below
            // stays a separate, focusable node.
            Semantics(
              container: true,
              label: 'Error: $title. $message',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: p.error),
                    const McGap.md(),
                    Text(
                      title,
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const McGap.xs(),
                    Text(
                      message,
                      style: text.bodyMedium!.copyWith(color: p.onSurfaceMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const McGap.lg(),
            McButton(label: retryLabel, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
