// The T-0065 review round (ADR-0015 fix round): a dropped file with filled
// keep regions, `**/` globs, results independent of which modules are named,
// and a broken tool configuration reported instead of crashing.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _dir = 'utility/mc_hello';
const _farewell = '$_dir/lib/src/farewell.dart';

List<String> _lines(String s) =>
    s.trim().isEmpty ? const [] : s.trim().split('\n');

/// The reference spec plus a second model, Farewell, with its own region.
String get _withFarewell => helloSpec.replaceFirst(
  'keep: [greeting.render]',
  '  - name: Farewell\n    fields:\n      - {name: name, type: String}\nkeep: [greeting.render]',
);

Run _gen(Directory root, [List<String> extra = const []]) =>
    mcgen(['gen', '--root', root.path, ...extra, 'mc_hello']);

void main() {
  group('T-0065-AC2 a file that is no longer generated', () {
    late Directory root;
    setUp(() {
      root = helloRoot('drop', spec: _withFarewell);
      addTearDown(() => root.deleteSync(recursive: true));
      expect(_gen(root).code, 0);
      expect(File(p.join(root.path, _farewell)).existsSync(), isTrue);
    });

    test('T-0065-AC2 with only its default keep bodies, it is deleted', () {
      writeFile(root, '$_dir/mcgen.yaml', helloSpec);
      final r = _gen(root);
      expect(r.code, 0, reason: '$r');
      expect(_lines(r.out), [
        '$_dir: wrote 3 file(s)',
        '  update $_dir/lib/mc_hello.dart',
        '  delete $_farewell',
        '  write $_dir/.mcgen/manifest.json',
      ]);
      expect(File(p.join(root.path, _farewell)).existsSync(), isFalse);
    });

    test('T-0065-AC2 with a filled keep region, gen refuses and names it; --force deletes and logs it', () {
      final f = File(p.join(root.path, _farewell));
      f.writeAsStringSync(
        f.readAsStringSync().replaceFirst(
          RegExp(r"    return 'Hi.*\n|    return '[A-Za-z]+, Farewell.*\n"),
          "    return 'Bye, \$name'; // hand-written\n",
        ),
      );
      expect(f.readAsStringSync(), contains('// hand-written'));
      writeFile(root, '$_dir/mcgen.yaml', helloSpec);
      final before = snapshot(p.join(root.path, _dir));

      final r = _gen(root);
      expect(r.code, 1);
      expect(_lines(r.err), [
        'mcgen gen: refusing to write anything: 1 drifted file(s)',
        '  $_farewell: orphan-keep: no longer generated, but keep region(s) farewell.render hold code',
        'remedies: move the edit into a keep region or the spec, add the file to owned: (mixed modules), or pass --force',
      ]);
      expect(snapshot(p.join(root.path, _dir)), before);

      final forced = _gen(root, ['--force']);
      expect(forced.code, 0);
      expect(
        _lines(forced.out),
        contains('  delete $_farewell (forced over orphan-keep)'),
      );
      expect(f.existsSync(), isFalse);
    });
  });

  test('T-0065-AC2 check and gen agree on a deleted managed file: stale, recreated', () {
    final root = helloRoot('deleted');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(_gen(root).code, 0);
    File(p.join(root.path, '$_dir/lib/src/mood.dart')).deleteSync();
    final c = mcgen(['check', '--root', root.path, 'mc_hello']);
    expect(c.code, 1);
    expect(_lines(c.err), [
      '$_dir/lib/src/mood.dart: stale-manifest: deleted: gen would create it again',
    ]);
    final g = _gen(root);
    expect(g.code, 0);
    expect(_lines(g.out), [
      '$_dir: wrote 1 file(s)',
      '  create $_dir/lib/src/mood.dart',
    ]);
    expect(mcgen(['check', '--root', root.path, 'mc_hello']).code, 0);
  });

  group('T-0065-AC2 keep defaults in the manifest', () {
    test('T-0065-AC2 the manifest records each region\'s default-body hash', () {
      final m = Manifest.decode(
        readFile(
          Directory(p.join(mcgenDir, 'test', 'golden')),
          'utility_hello/.mcgen/manifest.json',
        ),
      );
      const body =
          "    return 'Welcome, Greeting(name: \$name, mood: \$mood, excited: \$excited)';";
      expect(m.files['lib/src/greeting.dart']!.keep, {
        'greeting.render': bodyHash([body]),
      });
      // sha256("a"), the standard test vector.
      expect(
        bodyHash(['a']),
        'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
      );
    });

    test('T-0065-AC2 an untouched dropped region is not an orphan; a filled one is', () {
      const old = '// mcgen:keep a\n  def();\n// mcgen:end a\n';
      final defaults = {
        'a': bodyHash(['  def();']),
      };
      expect(
        spliceKeepRegions('x\n', old, '//', defaults: defaults).orphans,
        isEmpty,
      );
      expect(
        spliceKeepRegions(
          'x\n',
          old.replaceFirst('def', 'mine'),
          '//',
          defaults: defaults,
        ).orphans,
        ['a'],
      );
    });

    test('T-0065-AC2 a malformed keep list or ownership is a malformed manifest', () {
      String manifest(String entry) =>
          '{"archetype":"a","files":{"x.dart":$entry},"generator":"g","module":"m",'
          '"ownership":"managed","schema":"mcgen-manifest/1","seed":"0x0","spec_hash":"h"}';
      expect(
        () => Manifest.decode(
          manifest('{"hash":"h","ownership":"managed","keep":["a"]}'),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'files["x.dart"].keep must map region ids to hashes',
          ),
        ),
      );
      expect(
        () => Manifest.decode(manifest('{"hash":"h","ownership":"ejected"}')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'files["x.dart"].ownership must be managed or owned',
          ),
        ),
      );
    });
  });

  group('T-0065-AC2 owned globs', () {
    test('T-0065-AC2 **/ matches zero or more directories', () {
      final g = globToRegExp('lib/**/*.dart');
      expect(g.hasMatch('lib/x.dart'), isTrue);
      expect(g.hasMatch('lib/a/x.dart'), isTrue);
      expect(g.hasMatch('lib/a/b/x.dart'), isTrue);
      expect(g.hasMatch('test/x.dart'), isFalse);
      final top = globToRegExp('**/*.g.dart');
      expect(top.hasMatch('x.g.dart'), isTrue);
      expect(top.hasMatch('lib/src/x.g.dart'), isTrue);
      expect(top.hasMatch('lib/src/x.dart'), isFalse);
      expect(globToRegExp('lib/*.dart').hasMatch('lib/a/x.dart'), isFalse);
      expect(
        globToRegExp('.mcgen/**').hasMatch('.mcgen/manifest.json'),
        isTrue,
      );
    });

    test('T-0065-AC2 a mixed module owns lib/**/*.dart files at the top of lib/ too', () {
      final spec = helloSpec
          .replaceFirst('ownership: managed', 'ownership: mixed')
          .replaceFirst(
            'keep: [greeting.render]',
            'keep: [greeting.render]\nowned: ["lib/**/*.dart"]',
          );
      final root = helloRoot('owned-glob', spec: spec);
      addTearDown(() => root.deleteSync(recursive: true));
      expect(_gen(root).code, 0);
      final m = Manifest.decode(readFile(root, '$_dir/.mcgen/manifest.json'));
      expect(
        {for (final e in m.files.entries) e.key: e.value.ownership},
        {
          'lib/mc_hello.dart': 'owned',
          'lib/src/greeting.dart': 'owned',
          'lib/src/mood.dart': 'owned',
          'pubspec.yaml': 'managed',
        },
      );
    });
  });

  group('T-0065-AC4 results do not depend on which modules are named', () {
    test('T-0065-AC4 gen of one module sees a dependency that exists only as a spec', () {
      final root = helloRoot(
        'spec-dep',
        spec: helloSpec.replaceFirst(
          'seed_salt: 0',
          'seed_salt: 0\ndeps: [mc_base]',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(
        root,
        'utility/mc_base/mcgen.yaml',
        helloSpec.replaceFirst('module: mc_hello', 'module: mc_base'),
      );
      final r = _gen(root);
      expect(r.code, 0, reason: '$r');
      expect(
        readFile(root, '$_dir/pubspec.yaml'),
        endsWith('dependencies:\n  mc_base: any\n  meta: ^1.15.0\n'),
      );
      expect(
        File(p.join(root.path, 'utility/mc_base/pubspec.yaml')).existsSync(),
        isFalse,
        reason: 'only the target is written',
      );
      expect(mcgen(['check', '--root', root.path, 'mc_hello']).code, 0);
    });

    test('T-0065-AC4 lint catches a module collision when only one of the two specs is named', () {
      final root = helloRoot('one-named');
      addTearDown(() => root.deleteSync(recursive: true));
      writeFile(root, 'utility/mc_two/mcgen.yaml', helloSpec);
      final r = mcgen(['spec', 'lint', '--root', root.path, 'mc_hello']);
      expect(r.code, 1);
      expect(_lines(r.err), [
        'utility/mc_hello/mcgen.yaml:5:9: error [name-collision] module: module "mc_hello" is also specified by utility/mc_two/mcgen.yaml',
      ]);
      expect(_lines(r.out), ['mcgen spec lint: 1 spec(s), 1 error(s)']);
    });

    test(
      'T-0065-AC4 a broken spec that is not named does not stop another module',
      () {
        final root = helloRoot('broken-other');
        addTearDown(() => root.deleteSync(recursive: true));
        writeFile(
          root,
          'utility/mc_bad/mcgen.yaml',
          'schema: mcgen/1\nmodule: [\n',
        );
        expect(_gen(root).code, 0);
        final bad = mcgen(['spec', 'lint', '--root', root.path, 'mc_bad']);
        expect(bad.code, 1);
        expect(
          _lines(bad.err).single,
          startsWith('utility/mc_bad/mcgen.yaml:3:1: error [yaml] '),
        );
      },
    );

    test('T-0065-AC4 an enum default must be one of its values', () {
      final root = helloRoot(
        'enum-default',
        spec: helloSpec.replaceFirst('default: calm', 'default: angry'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['spec', 'lint', '--root', root.path, 'mc_hello']);
      expect(r.code, 1);
      expect(_lines(r.err), [
        'utility/mc_hello/mcgen.yaml:16:43: error [utility_hello] entities[0].fields[1].default: default "angry" is not a value of Mood (calm, cheerful)',
      ]);
    });
  });

  group('a broken tool configuration is a diagnostic, not a crash', () {
    Directory toolCopy(String tag) {
      final d = tempRoot(tag);
      addTearDown(() => d.deleteSync(recursive: true));
      for (final rel in ['mcgen.yaml', 'schema/mcgen-1.json']) {
        writeFile(d, rel, File(p.join(mcgenDir, rel)).readAsStringSync());
      }
      return d;
    }

    Run run(Directory tool) {
      final root = helloRoot('${p.basename(tool.path)}-root');
      addTearDown(() => root.deleteSync(recursive: true));
      final out = StringBuffer();
      final err = StringBuffer();
      final code = runMcgen(
        ['gen', '--root', root.path, 'mc_hello'],
        out: out,
        err: err,
        toolDir: tool.path,
      );
      return Run(code, '$out', '$err');
    }

    test('a mcgen.yaml without global_seed', () {
      final tool = toolCopy('cfg-seed');
      writeFile(tool, 'mcgen.yaml', 'dart: {language_version: "3.13"}\n');
      final r = run(tool);
      expect(r.code, 1);
      expect(_lines(r.err), [
        'tool/mcgen/mcgen.yaml: error [config] "global_seed" must be a int',
      ]);
    });

    test('a mcgen.yaml that is not YAML', () {
      final tool = toolCopy('cfg-yaml');
      writeFile(tool, 'mcgen.yaml', 'global_seed: [1\n');
      final r = run(tool);
      expect(r.code, 1);
      expect(_lines(r.err).first, startsWith('mcgen: '));
      expect(r.err, isNot(contains('#0 ')), reason: 'no stack trace');
    });

    test('a schema that is not JSON, and one with an unsupported keyword', () {
      final tool = toolCopy('schema-json');
      writeFile(tool, 'schema/mcgen-1.json', '{"type": ');
      final r = run(tool);
      expect(r.code, 1);
      expect(_lines(r.err).first, startsWith('mcgen: '));
      final tool2 = toolCopy('schema-kw');
      writeFile(
        tool2,
        'schema/mcgen-1.json',
        '{"type": "object", "oneOf": []}',
      );
      final r2 = run(tool2);
      expect(r2.code, 1);
      expect(_lines(r2.err), [
        'mcgen: unsupported schema keyword "oneOf" at #',
      ]);
    });

    test('a missing config file', () {
      final tool = toolCopy('cfg-missing');
      File(p.join(tool.path, 'mcgen.yaml')).deleteSync();
      final r = run(tool);
      expect(r.code, 1);
      expect(_lines(r.err).single, startsWith('mcgen: Cannot open file: '));
    });
  });
}
