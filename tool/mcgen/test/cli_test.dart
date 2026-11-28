// The command surface (task scope): stubs, usage, `gen --out`, and the
// round-trip harness P2-04 to P2-07 use for their exemplar goldens
// (T-0065-AC1: output equals a reference tree byte for byte).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

List<String> _lines(String s) =>
    s.trim().isEmpty ? const [] : s.trim().split('\n');

GeneratedModule _render(Directory root) {
  final tool = ToolLayout(mcgenDir);
  final cfg = tool.loadConfig();
  final spec = loadSpec(
    text: helloSpec,
    file: 'utility/mc_hello/mcgen.yaml',
    schema: schema,
  );
  return Generator(
    config: cfg,
    archetypes: archetypes,
    bricks: BrickSet(tool.bricksDir),
    formatter: DartFormatter(cfg),
  ).generate(spec, index: RepoIndex.scan(root.path), forbidden: [root.path]);
}

void main() {
  group(
    'commands not built yet exit non-zero and say which task builds them',
    () {
      const expected = {
        'spec synth x': 'mcgen spec synth: not yet (P2-09)',
        // wire and buildgen exist since T-0074 (wire_test, buildgen_test).
        'owners --verify T-0001': 'mcgen owners: not yet (P2-08)',
        'new list_detail x': 'mcgen new: not yet (P2-08)',
        'synth --target-loc 5': 'mcgen synth: not yet (P2-15)',
        'stats': 'mcgen stats: not yet (P2-09)',
      };
      expected.forEach((args, message) {
        test('mcgen $args', () {
          final r = mcgen(args.split(' '));
          expect(r.code, 3);
          expect(_lines(r.err), [message]);
          expect(r.out, '');
        });
      });
    },
  );

  test('usage errors exit 64', () {
    expect(mcgen([]).code, 64);
    expect(mcgen(['frobnicate']).code, 64);
    expect(
      mcgen(['gen', '--root', mcgenDir]).err,
      'mcgen: name at least one module, or pass --all\n',
    );
    expect(mcgen(['gen', '--bogus']).code, 64);
    expect(mcgen(['help']).code, 0);
  });

  test('a module name that has no spec is a usage error', () {
    final root = tempRoot('nospec');
    addTearDown(() => root.deleteSync(recursive: true));
    final r = mcgen(['gen', '--root', root.path, 'mc_none']);
    expect(r.code, 64);
    expect(
      r.err,
      'mcgen: no spec for module "mc_none" under app/, feature/ or utility/\n',
    );
  });

  test(
    'gen --out renders one module into an empty directory, ignoring ownership',
    () {
      final root = helloRoot(
        'out',
        spec: helloSpec.replaceFirst(
          'ownership: managed',
          'ownership: ejected',
        ),
      );
      final out = tempRoot('out-dir');
      addTearDown(() {
        root.deleteSync(recursive: true);
        out.deleteSync(recursive: true);
      });
      final r = mcgen([
        'gen',
        '--root',
        root.path,
        '--out',
        out.path,
        'mc_hello',
      ]);
      expect(r.code, 0, reason: '$r');
      final tree = snapshot(out.path);
      final golden = snapshot(
        p.join(mcgenDir, 'test', 'golden', 'utility_hello'),
      );
      expect(tree.keys, golden.keys);
      // Only the manifest's ownership line differs from the managed golden.
      for (final k in golden.keys.where((k) => k != '.mcgen/manifest.json')) {
        expect(tree[k], golden[k], reason: k);
      }
      expect(
        Manifest.decode(tree['.mcgen/manifest.json']!).ownership,
        'ejected',
      );
      expect(
        mcgen(['gen', '--root', root.path, '--out', out.path, 'mc_hello']).code,
        64,
        reason: 'not empty',
      );
    },
  );

  group('T-0065-AC1 the round-trip harness', () {
    test('T-0065-AC1 the reference golden round-trips exactly', () {
      final root = helloRoot('rt');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root);
      final diff = compareToExemplar(
        gen,
        p.join(mcgenDir, 'test', 'golden', 'utility_hello'),
      );
      expect(diff.identical, isTrue, reason: '$diff');
    });

    test('T-0065-AC1 an exemplar without the header and with other keep bodies still matches', () {
      final root = helloRoot('rt-ex');
      final ex = tempRoot('rt-exemplar');
      addTearDown(() {
        root.deleteSync(recursive: true);
        ex.deleteSync(recursive: true);
      });
      final gen = _render(root);
      gen.files.forEach((path, f) {
        var text = f.content.substring(headerFor(path)?.length ?? 0);
        if (path == 'lib/src/greeting.dart') {
          text = text.replaceFirst(
            RegExp(r"    return 'Welcome.*\n"),
            "    return name; // hand-written\n",
          );
        }
        writeFile(ex, path, text);
      });
      writeFile(ex, 'lib/src/greeting.g.dart', '// ide_sync output, ignored\n');
      expect(compareToExemplar(gen, ex.path).identical, isTrue);

      File(p.join(ex.path, 'lib/src/mood.dart'))
          .writeAsStringSync('enum Mood { calm }\n');
      writeFile(ex, 'lib/src/extra.dart', 'const x = 1;\n');
      File(p.join(ex.path, 'pubspec.yaml')).deleteSync();
      final diff = compareToExemplar(gen, ex.path);
      expect(diff.onlyGenerated, ['pubspec.yaml']);
      expect(diff.onlyExemplar, ['lib/src/extra.dart']);
      expect(diff.differing, {
        'lib/src/mood.dart':
            'line 1: /// How a greeting sounds. | enum Mood { calm }',
      });
    });
  });
}
