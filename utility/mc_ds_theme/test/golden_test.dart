import 'package:flutter/material.dart';
import 'package:mc_ds_testing/mc_ds_testing.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Type scale and palette swatches: the "theme" component.
class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final swatches = <(String, Color, Color)>[
      ('primary', p.primary, p.onPrimary),
      ('surface', p.surface, p.onSurface),
      ('variant', p.surfaceVariant, p.onSurface),
      ('error', p.error, p.onError),
    ];
    return Padding(
      padding: const EdgeInsets.all(McSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Display', style: McTypeScale.display),
          Text('Title', style: Theme.of(context).textTheme.headlineMedium),
          Text('Headline', style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Body: the quick brown fox 0123456789',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text('Caption', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: McSpacing.lg),
          Wrap(
            spacing: McSpacing.sm,
            runSpacing: McSpacing.sm,
            children: [
              for (final (name, bg, fg) in swatches)
                Container(
                  padding: const EdgeInsets.all(McSpacing.md),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: McRadius.mdAll,
                    border: Border.all(color: p.outline),
                  ),
                  child: Text(
                    name,
                    style: McTypeScale.label.copyWith(color: fg),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'theme_sheet',
    builder: (_) => const _ThemeSheet(),
    height: 360,
    heightAtScale2: 760,
  );
}
