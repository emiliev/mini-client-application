// T-0069-AC4, P-120 (a): the shared format gate skips mason brick templates.
// A `.dart` template is mustache, not Dart, so `dart format` cannot parse it;
// the gate must leave every `__brick__/` alone and still format the rest.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

/// A throwaway git repo holding a copy of the gate, a brick with a `.dart`
/// template, and one ordinary Dart file.
Directory _repo(String ordinary) {
  final root = tempRoot('format-gate');
  final gate = File(p.join(repoRoot, 'tool/checks/lib/format_gate.sh'));
  writeFile(root, 'tool/checks/lib/format_gate.sh', gate.readAsStringSync());
  // The gate runs `pub get` only when this is missing.
  writeFile(root, '.dart_tool/package_config.json', '{"configVersion": 2}\n');
  writeFile(
    root,
    'tool/kit/bricks/b/__brick__/lib/{{name}}.dart',
    'class {{name}} {{#fields}}{{{type}}} {{name}};{{/fields}}\n',
  );
  writeFile(root, 'tool/kit/bricks/b/brick.yaml', 'name: b\n');
  writeFile(root, 'tool/kit/lib/ordinary.dart', ordinary);
  writeFile(root, 'app/a.dart', 'class A {}\n');
  final git = Process.runSync('git', ['init', '-q', root.path]);
  expect(git.exitCode, 0, reason: '${git.stderr}');
  return root;
}

ProcessResult _gate(Directory root) => Process.runSync('bash', [
  p.join(root.path, 'tool/checks/lib/format_gate.sh'),
], workingDirectory: root.path);

void main() {
  group('T-0069-AC4 P-120 (a) the format gate and brick templates', () {
    test(
      'T-0069-AC4 a .dart template under __brick__ does not fail the gate',
      () {
        final root = _repo('class Ordinary {}\n');
        addTearDown(() => root.deleteSync(recursive: true));
        final r = _gate(root);
        expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
        expect('${r.stdout}', contains('Formatted 2 files (0 changed)'));
      },
    );

    test('T-0069-AC4 an unformatted file beside a brick still fails it', () {
      final root = _repo('class   Ordinary {   }\n');
      addTearDown(() => root.deleteSync(recursive: true));
      final r = _gate(root);
      expect(r.exitCode, isNot(0));
      expect('${r.stdout}', contains('tool/kit/lib/ordinary.dart'));
    });
  });
}
