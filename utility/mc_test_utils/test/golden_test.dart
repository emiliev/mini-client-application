import 'package:flutter/material.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

void main() {
  // One tiny widget across the theme x text-scale matrix: proves the golden
  // helpers moved from mc_ds_testing (P-033) still render with real fonts.
  mcGoldenMatrix(
    acId: 'T-0026-AC4',
    component: 'probe',
    width: 120,
    height: 60,
    heightAtScale2: 90,
    settle: const Duration(milliseconds: 10),
    builder: (context) =>
        const Padding(padding: EdgeInsets.all(8), child: Text('Wiimm 123')),
  );
}
