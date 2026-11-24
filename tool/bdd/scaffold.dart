// T-0029: `tool/bazelw run //tool/bdd:scaffold -- <package>...`
//
// <package> is a Bazel label (`//feature/x`) or a workspace-relative
// directory. Writes a stub (`/// Usage:` line, `UnimplementedError` body) into
// `<package>/test/feature/step/` for every step of the package's
// `test/feature/*.feature` files that neither the package nor a step index
// (`--step-index`, set by the BUILD target to mc_test_steps' `:step_index`)
// defines. Existing files are never touched. `--workspace <dir>` overrides
// BUILD_WORKSPACE_DIRECTORY (for tests).
import 'dart:io';

import 'package:rules_dart_ext_bdd/bdd_generator.dart';
import 'package:rules_dart_ext_bdd/scaffold.dart';

// The same options `mc_bdd_tests` passes to the generator, minus the test
// file's headers (stubs import only flutter_test).
const _config = {'dataTableImport': 'package:mc_test_steps/mc_test_steps.dart'};

void main(List<String> args) {
  var workspace = Platform.environment['BUILD_WORKSPACE_DIRECTORY'];
  final indexes = <String>[];
  final packages = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--workspace' && i + 1 < args.length) {
      workspace = args[++i];
    } else if (a.startsWith('--step-index=')) {
      indexes.add(a.substring('--step-index='.length));
    } else {
      packages.add(a.replaceFirst(RegExp('^//'), '').split(':').first);
    }
  }
  if (workspace == null || packages.isEmpty) {
    stderr.writeln(
      'usage: tool/bazelw run //tool/bdd:scaffold -- //<package> [...]',
    );
    exitCode = 2;
    return;
  }
  try {
    final shared = readStepIndexes(indexes);
    for (final dir in packages) {
      final pubspec = File('$workspace/$dir/pubspec.yaml');
      final text = pubspec.existsSync() ? pubspec.readAsStringSync() : '';
      final name = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(text)?.group(1);
      if (name == null) {
        stderr.writeln('scaffold: no pubspec.yaml with a name in $dir');
        exitCode = 2;
        return;
      }
      final written = scaffoldPackage(
        workspace: workspace,
        packageDir: dir,
        package: name,
        sharedSteps: shared,
        config: _config,
        languageVersion: languageVersionOf(text) ?? '3.0',
      );
      stdout.writeln(
        written.isEmpty
            ? 'scaffold: $dir: every step is defined'
            : written.map((w) => 'scaffold: wrote $w').join('\n'),
      );
    }
  } on BddGenerationError catch (e) {
    stderr.writeln('scaffold: $e');
    exitCode = 1;
  } on FormatException catch (e) {
    stderr.writeln('scaffold: ${e.message}');
    exitCode = 1;
  } on FileSystemException catch (e) {
    stderr.writeln('scaffold: $e');
    exitCode = 1;
  }
}
