import 'dart:io';

import 'package:l10n_check/l10n_check.dart';
import 'package:test/test.dart';

/// The gate: every ARB set in the workspace (the `arbs` filegroups listed in
/// this package's BUILD.bazel `workspace_gate_test` data) is complete.
void main() {
  test('T-0025-AC3 the workspace ARB sets are complete (gate)', () {
    final root = Directory.current.path;
    final arbs = Directory(root)
        .listSync(recursive: true, followLinks: false)
        .where((e) => e.path.endsWith('.arb'))
        .toList();
    expect(arbs, isNotEmpty, reason: 'no ARB files in runfiles at $root');
    expect(checkL10n(root), isEmpty);
  });
}
