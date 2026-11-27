// T-0065-AC1 (templates): bricks render strictly and deterministically in
// mason's brick format.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

Brick _brick(
  Map<String, String> templates, {
  String vars = 'vars:\n  name: {type: string}\n  on: {type: boolean}\n',
}) {
  final dir = tempRoot('brick');
  addTearDown(() => dir.deleteSync(recursive: true));
  writeFile(dir, 'b/brick.yaml', 'name: b\n$vars');
  templates.forEach((k, v) => writeFile(dir, 'b/__brick__/$k', v));
  return Brick.load(p.join(dir.path, 'b'));
}

void main() {
  group('T-0065-AC1 bricks', () {
    test(
      'T-0065-AC1 renders paths and contents; {{x}} escapes as in mason, {{{x}}} is raw',
      () {
        final b = _brick({
          'lib/{{{name}}}.dart': "const n = '{{{name}}}'; // {{name}}\n",
        });
        expect(b.render({'name': 'a<b>&', 'on': false}), {
          'lib/a<b>&.dart': "const n = 'a<b>&'; // a&lt;b&gt;&amp;\n",
        });
      },
    );

    test('T-0065-AC1 standalone section lines vanish (mustache spec)', () {
      final b = _brick({'x.yaml': 'a: 1\n{{#on}}\nb: 2\n{{/on}}\nc: 3\n'});
      expect(
        b.render({'name': 'n', 'on': true})['x.yaml'],
        'a: 1\nb: 2\nc: 3\n',
      );
      expect(b.render({'name': 'n', 'on': false})['x.yaml'], 'a: 1\nc: 3\n');
    });

    test(
      'T-0065-AC1 a path that renders empty is skipped (conditional file)',
      () {
        final b = _brick({
          '{{#on}}extra.txt{{/on}}': 'x\n',
          'always.txt': 'y\n',
        });
        expect(b.render({'name': 'n', 'on': false}).keys, ['always.txt']);
        expect(b.render({'name': 'n', 'on': true}).keys, [
          'always.txt',
          'extra.txt',
        ]);
      },
    );

    test('T-0065-AC1 missing, undeclared and unknown variables are errors', () {
      final b = _brick({'a.txt': '{{name}} {{other}}\n'});
      expect(
        () => b.render({'name': 'n'}),
        throwsA(
          isA<BrickError>().having(
            (e) => e.message,
            'message',
            'brick "b": missing on',
          ),
        ),
      );
      expect(
        () => b.render({'name': 'n', 'on': true, 'x': 1}),
        throwsA(
          isA<BrickError>().having(
            (e) => e.message,
            'message',
            'brick "b": not declared in brick.yaml: x',
          ),
        ),
      );
      expect(
        () => b.render({'name': 'n', 'on': true}),
        throwsA(
          isA<BrickError>().having(
            (e) => e.message,
            'message',
            contains('Value was missing for variable tag: other'),
          ),
        ),
      );
    });

    test('T-0065-AC1 unsafe output paths are refused', () {
      final b = _brick({'{{name}}/x.txt': 'x\n'});
      expect(
        () => b.render({'name': '..', 'on': true}),
        throwsA(isA<BrickError>()),
      );
    });

    test('T-0065-AC1 the utility_hello brick is a valid mason brick', () {
      final b = Brick.load(p.join(mcgenDir, 'bricks', 'utility_hello'));
      expect(b.vars, {
        'name',
        'description',
        'sdk',
        'has_dependencies',
        'dependencies',
      });
      final out = b.render({
        'name': 'mc_x',
        'description': 'X.',
        'sdk': '^3.13.0',
        'has_dependencies': false,
        'dependencies': <Object?>[],
      });
      expect(out, {
        'pubspec.yaml':
            'name: mc_x\ndescription: X.\nversion: 0.1.0\npublish_to: none\nresolution: workspace\n\n'
            'environment:\n  sdk: ^3.13.0\n',
      });
      expect(
        File(p.join(mcgenDir, 'bricks', 'utility_hello', 'brick.yaml'))
            .readAsStringSync(),
        contains('name: utility_hello'),
      );
    });
  });
}
