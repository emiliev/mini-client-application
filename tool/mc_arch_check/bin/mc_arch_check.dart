import 'dart:io';

import 'package:mc_arch_check/mc_arch_check.dart';

/// `mc_arch_check [root]`. Fails with exit code 1 when a rule is violated.
///
/// Without an argument the root is `BUILD_WORKSPACE_DIRECTORY` (set by
/// `bazel run`), else the current directory.
void main(List<String> args) {
  final root = args.isNotEmpty
      ? args.first
      : Platform.environment['BUILD_WORKSPACE_DIRECTORY'] ?? '.';
  final violations = checkArchitecture(root);
  if (violations.isEmpty) {
    stdout.writeln('mc_arch_check: OK ($root)');
    return;
  }
  for (final violation in violations) {
    stderr.writeln(violation);
  }
  stderr.writeln('mc_arch_check: ${violations.length} violation(s) in $root');
  exitCode = 1;
}
