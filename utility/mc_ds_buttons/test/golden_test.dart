import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_testing/mc_ds_testing.dart';

Widget _buttons(BuildContext context) {
  return Padding(
    padding: McInsets.screen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McButton(label: 'Primary', onPressed: () {}),
        const McGap.md(),
        McButton(
          label: 'Secondary',
          variant: McButtonVariant.secondary,
          onPressed: () {},
        ),
        const McGap.md(),
        McButton(
          label: 'Tertiary',
          variant: McButtonVariant.tertiary,
          onPressed: () {},
        ),
        const McGap.md(),
        const McButton(label: 'Disabled', onPressed: null),
        const McGap.md(),
        const McButton(
          label: 'Disabled secondary',
          variant: McButtonVariant.secondary,
          onPressed: null,
        ),
        const McGap.md(),
        Row(
          children: [
            McIconButton(
              icon: Icons.search,
              semanticLabel: 'Search',
              onPressed: () {},
            ),
            McIconButton(
              icon: Icons.close,
              semanticLabel: 'Close',
              onPressed: () {},
            ),
            const McIconButton(
              icon: Icons.add,
              semanticLabel: 'Add',
              onPressed: null,
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  mcGoldenMatrix(
    acId: 'T-0019-AC1',
    component: 'buttons',
    builder: _buttons,
    height: 440,
    heightAtScale2: 640,
  );
}
