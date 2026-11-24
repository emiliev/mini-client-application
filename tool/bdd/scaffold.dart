// T-0029: `tool/bazelw run //tool/bdd:scaffold -- <package>...`
//
// <package> is a Bazel label (`//feature/x`) or a workspace-relative
// directory. Writes a stub (`/// Usage:` line, `UnimplementedError` body) into
// `<package>/test/feature/step/` for every step that neither the package nor
// mc_test_steps defines. Existing files are never touched. `--workspace <dir>`
// overrides BUILD_WORKSPACE_DIRECTORY (for tests).
import 'dart:io';

import 'package:rules_dart_ext_bdd/bdd_generator.dart';
import 'package:rules_dart_ext_bdd/scaffold.dart';

const _sharedStepDirs = ['utility/mc_test_steps/lib/src'];
const _config = {'dataTableImport': 'package:mc_test_steps/mc_test_steps.dart'};

void main(List<String> args) {
  var workspace = Platform.environment['BUILD_WORKSPACE_DIRECTORY'];
  final packages = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--workspace' && i + 1 < args.length) {
      workspace = args[++i];
    } else {
      packages.add(args[i].replaceFirst(RegExp('^//'), '').split(':').first);
    }
  }
  if (workspace == null || packages.isEmpty) {
    stderr.writeln(
      'usage: tool/bazelw run //tool/bdd:scaffold -- //<package> [...]',
    );
    exitCode = 2;
    return;
  }
  final shared = scanSharedSteps(workspace, _sharedStepDirs);
  for (final dir in packages) {
    final pubspec = File('$workspace/$dir/pubspec.yaml');
    final name = pubspec.existsSync()
        ? RegExp(
            r'^name:\s*(\S+)',
            multiLine: true,
          ).firstMatch(pubspec.readAsStringSync())?.group(1)
        : null;
    if (name == null) {
      stderr.writeln('scaffold: no pubspec.yaml with a name in $dir');
      exitCode = 2;
      return;
    }
    try {
      final written = scaffoldPackage(
        workspace: workspace,
        packageDir: dir,
        package: name,
        sharedSteps: shared,
        config: _config,
      );
      stdout.writeln(
        written.isEmpty
            ? 'scaffold: $dir: every step is defined'
            : written.map((w) => 'scaffold: wrote $w').join('\n'),
      );
    } on BddGenerationError catch (e) {
      stderr.writeln('scaffold: $e');
      exitCode = 1;
    } on FormatException catch (e) {
      stderr.writeln('scaffold: $dir: ${e.message}');
      exitCode = 1;
    }
  }
}
