import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// `dart test` runs in the package; Bazel runs in the runfiles root.
String _find(String relativeToPackage) {
  for (final base in const [
    '.',
    'utility/mc_analysis',
    '_main/utility/mc_analysis',
  ]) {
    final entity = FileSystemEntity.typeSync('$base/$relativeToPackage');
    if (entity != FileSystemEntityType.notFound) {
      return Directory('$base/$relativeToPackage').absolute.path
          .replaceAll(RegExp(r'/\.?$'), '');
    }
  }
  throw StateError('$relativeToPackage not found from ${Directory.current}');
}

/// The rules the shared options enable, read from the file itself.
Set<String> _enabledRules() {
  final yaml = loadYaml(
    File(_find('lib/analysis_options.yaml')).readAsStringSync(),
  );
  return (yaml['linter']['rules'] as YamlList).cast<String>().toSet();
}

/// The `strict-inference` language flag is not a lint rule.
const _strictInferenceFixture = 'strict_inference';
const _strictInferenceCode = 'INFERENCE_FAILURE_ON_COLLECTION_LITERAL';

/// Machine-format lines: SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE.
Future<Map<String, Set<String>>> _analyse(Directory project) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'analyze',
    '--format=machine',
    project.path,
  ]);
  final byFile = <String, Set<String>>{};
  for (final line in '${result.stdout}\n${result.stderr}'.split('\n')) {
    final parts = line.split('|');
    if (parts.length < 8) {
      continue;
    }
    final file = parts[3].split('/').last.replaceAll('.dart', '');
    byFile.putIfAbsent(file, () => <String>{}).add(parts[2]);
  }
  return byFile;
}

/// A throwaway package that includes the shared options, so the fixtures
/// need no package config of their own.
Directory _project(Map<String, String> files, {String name = 'lint_fixtures'}) {
  final dir = Directory.systemTemp.createTempSync('mc_analysis_');
  addTearDown(() => dir.deleteSync(recursive: true));
  File('${dir.path}/pubspec.yaml').writeAsStringSync(
    'name: $name\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\n',
  );
  File('${dir.path}/analysis_options.yaml')
      .writeAsStringSync('include: ${_find('lib/analysis_options.yaml')}\n');
  Directory('${dir.path}/.dart_tool').createSync();
  File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync(
    '{"configVersion": 2, "packages": [{"name": "$name", '
    '"rootUri": "../", "packageUri": "lib/", "languageVersion": "3.13"}]}',
  );
  Directory('${dir.path}/lib').createSync();
  files.forEach((path, text) {
    File('${dir.path}/lib/$path').writeAsStringSync(text);
  });
  return dir;
}

void main() {
  final fixtures = Directory(_find('test/fixtures/lints'));
  final fixtureFiles = {
    for (final f in fixtures.listSync().whereType<File>())
      f.path.split('/').last: f.readAsStringSync(),
  };

  test('T-0017-AC3 every enabled rule has a fixture', () {
    final fixtureNames = fixtureFiles.keys
        .map((n) => n.replaceAll('.dart', ''))
        .toSet();

    final missing = _enabledRules()
        .where((r) => r != 'package_names')
        .where((r) => !fixtureNames.contains(r));

    expect(missing, isEmpty);
    expect(_enabledRules(), hasLength(20));
  });

  test('T-0017-AC3 each rule reports on its fixture', () async {
    final reported = await _analyse(_project(fixtureFiles));

    for (final rule in _enabledRules().where((r) => r != 'package_names')) {
      expect(
        reported[rule] ?? const <String>{},
        contains(rule.toUpperCase()),
        reason: '$rule must report on its fixture',
      );
    }
  });

  test('T-0017-AC3 strict-inference reports', () async {
    final reported = await _analyse(_project(fixtureFiles));

    expect(reported[_strictInferenceFixture], contains(_strictInferenceCode));
  });

  test('T-0017-AC3 package_names reports on a badly named package', () async {
    final project = _project(const {
      'a.dart': 'void f() {}\n',
    }, name: 'Bad-Name');

    final reported = await _analyse(project);

    expect(reported['pubspec.yaml'] ?? reported['pubspec'], isNotNull);
    expect(reported.values.expand((c) => c), contains('PACKAGE_NAMES'));
  });

  test('T-0017-AC3 generated files are excluded', () async {
    final project = _project(const {
      'bad.g.dart': 'f() => 1;\n',
      'bad.freezed.dart': 'f() => 1;\n',
      'bad.config.dart': 'f() => 1;\n',
    });

    final reported = await _analyse(project);

    expect(reported.keys.where((k) => k.startsWith('bad')), isEmpty);
  });
}
