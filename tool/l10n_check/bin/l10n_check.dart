import 'dart:io';

import 'package:l10n_check/l10n_check.dart';

/// `l10n_check [root] [--locales en,de | --locales=en,de]`. Exits 1 when a
/// package's ARB set is incomplete, 2 on a usage error. Without a root it uses
/// `BUILD_WORKSPACE_DIRECTORY` (set by `bazel run`), else the current directory.
void main(List<String> args) {
  var locales = defaultRequiredLocales;
  String? root;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--locales' || arg.startsWith('--locales=')) {
      final String? value;
      if (arg.startsWith('--locales=')) {
        value = arg.substring('--locales='.length);
      } else {
        value = i + 1 < args.length ? args[++i] : null;
      }
      if (value == null || value.isEmpty) {
        stderr.writeln('l10n_check: --locales needs a value, e.g. en,de');
        exitCode = 2;
        return;
      }
      locales = value.split(',');
    } else if (arg.startsWith('-')) {
      stderr.writeln('l10n_check: unknown flag $arg');
      exitCode = 2;
      return;
    } else {
      root = arg;
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
