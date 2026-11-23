import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_golden.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

Widget _grid(BuildContext context) {
  final p = context.mcPalette;
  return McAdaptiveGrid(
    padding: McInsets.screen,
    childAspectRatio: 1.6,
    children: [
      for (var i = 1; i <= 8; i++)
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.surfaceVariant,
            borderRadius: McRadius.mdAll,
            border: Border.all(color: p.outline),
          ),
          child: Center(
            child: Text(
              'Tile $i',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
    ],
  );
}

void main() {
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'adaptive_grid_375',
    builder: _grid,
    height: 520,
    heightAtScale2: 520,
  );
  // Same grid on a 1024-wide surface: 4 columns (T-0019-AC3).
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'adaptive_grid_1024',
    builder: _grid,
    width: 1024,
    height: 340,
    heightAtScale2: 340,
  );
}
