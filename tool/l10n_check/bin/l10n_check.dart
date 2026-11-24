import 'dart:io';

import 'package:l10n_check/l10n_check.dart';

/// `l10n_check [root] [--locales en,de]`. Exits 1 when a package's ARB set is
/// incomplete. Without a root it uses `BUILD_WORKSPACE_DIRECTORY` (set by
/// `bazel run`), else the current directory.
void main(List<String> args) {
  var locales = defaultRequiredLocales;
  String? root;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--locales' && i + 1 < args.length) {
      locales = args[++i].split(',');
    } else {
      root = args[i];
    }
  }
  root ??= Platform.environment['BUILD_WORKSPACE_DIRECTORY'] ?? '.';
  final violations = checkL10n(root, requiredLocales: locales);
  if (violations.isEmpty) {
    stdout.writeln('l10n_check: OK ($root)');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln('l10n_check: ${violations.length} violation(s) in $root');
  exitCode = 1;
}
