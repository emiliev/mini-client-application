// T-0065-AC1 (gen is byte-stable and idempotent; --check) and T-0065-AC2
// (keep regions, the clobber guard, ownership modes, mcgen check), through
// the CLI on temporary roots.

import 'dart:convert';
import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _dir = 'utility/mc_hello';
const _greeting = '$_dir/lib/src/greeting.dart';
const _golden = 'test/golden/utility_hello';

Directory _root(String tag, {String? spec}) {
  final r = helloRoot(tag, spec: spec);
  addTearDown(() => r.deleteSync(recursive: true));
  return r;
}

Run _gen(Directory root, [List<String> extra = const []]) =>
    mcgen(['gen', '--root', root.path, ...extra, 'mc_hello']);

Run _check(Directory root) => mcgen(['check', '--root', root.path, 'mc_hello']);

List<String> _lines(String s) =>
    s.trim().isEmpty ? const [] : s.trim().split('\n');

Map<String, String> _module(Directory root) =>
    snapshot(p.join(root.path, _dir))..remove('mcgen.yaml');

/// The spec with an extra `count: int` field on Greeting.
String get _specWithCount => helloSpec.replaceFirst(
  '      - {name: excited, type: bool, default: false}\n',
  '      - {name: excited, type: bool, default: false}\n      - {name: count, type: int, default: 0}\n',
);

void _setSpec(Directory root, String spec) =>
    writeFile(root, '$_dir/mcgen.yaml', spec);

void main() {
  group('T-0065-AC1 gen is byte-stable and idempotent', () {
    test('T-0065-AC1 two roots with different absolute paths give identical trees, equal to the golden', () {
      final a = _root('a');
      final b = _root('b-with-a-longer-name');
      expect(a.path, isNot(b.path));
      final ra = _gen(a);
      final rb = _gen(b);
      expect(ra.code, 0, reason: '$ra');
      expect(rb.code, 0, reason: '$rb');
      expect(_lines(ra.out), [
        '$_dir: wrote 5 file(s)',
        '  create $_dir/lib/mc_hello.dart',
        '  create $_dir/lib/src/greeting.dart',
        '  create $_dir/lib/src/mood.dart',
        '  create $_dir/pubspec.yaml',
        '  write $_dir/.mcgen/manifest.json',
      ]);
      final ta = _module(a);
      expect(_module(b), ta);
      expect(hashTree(p.join(a.path, _dir)), hashTree(p.join(b.path, _dir)));
      expect(ta, snapshot(p.join(mcgenDir, _golden)));
      expect(ta.keys, [
        '.mcgen/manifest.json',
        'lib/mc_hello.dart',
        'lib/src/greeting.dart',
        'lib/src/mood.dart',
        'pubspec.yaml',
      ]);
    });

    test('T-0065-AC1 a second run reports no writes, and --check exits 0', () {
      final root = _root('twice');
      expect(_gen(root).code, 0);
      final before = _module(root);
      final again = _gen(root);
      expect(again.code, 0);
      expect(_lines(again.out), ['$_dir: no changes']);
      expect(again.err, '');
      expect(_module(root), before);
      final check = _gen(root, ['--check']);
      expect(check.code, 0);
      expect(_lines(check.out), ['$_dir: up to date']);
    });

    test(
      'T-0065-AC1 after a template change, --check exits 1 and lists the file',
      () {
        final root = _root('tpl');
        expect(_gen(root).code, 0);
        final bricks = tempRoot('bricks');
        addTearDown(() => bricks.deleteSync(recursive: true));
        final src = Directory(p.join(mcgenDir, 'bricks', 'utility_hello'));
        for (final f in src.listSync(recursive: true).whereType<File>()) {
          writeFile(
            bricks,
            p.join('utility_hello', p.relative(f.path, from: src.path)),
            f.readAsStringSync(),
          );
        }
        final tpl = File(
          p.join(bricks.path, 'utility_hello', '__brick__', 'pubspec.yaml'),
        );
        tpl.writeAsStringSync(
          tpl.readAsStringSync().replaceFirst(
            'version: 0.1.0',
            'version: 0.2.0',
          ),
        );
        final before = _module(root);
        final r = _gen(root, ['--check', '--bricks', bricks.path]);
        expect(r.code, 1);
        expect(_lines(r.out), [
          '$_dir: out of date',
          '  would update $_dir/pubspec.yaml',
          '  would write $_dir/.mcgen/manifest.json',
        ]);
        expect(_module(root), before, reason: '--check writes nothing');
      },
    );

    test('T-0065-AC1 after a spec change, --check lists exactly the files that change', () {
      final root = _root('spec');
      expect(_gen(root).code, 0);
      _setSpec(root, _specWithCount);
      final r = _gen(root, ['--check']);
      expect(r.code, 1);
      expect(_lines(r.out), [
        '$_dir: out of date',
        '  would update $_greeting',
        '  would write $_dir/.mcgen/manifest.json',
      ]);
    });
  });

  group('T-0065-AC2 keep regions and the clobber guard', () {
    const handBody = "    // Hand-written.\n    return 'Ahoy, \$name';";

    String editRegion(String content) {
      final scan = KeepScan.of(content, '//');
      final r = scan['greeting.render']!;
      final lines = content.split('\n');
      return [
        ...lines.sublist(0, r.start + 1),
        handBody,
        ...lines.sublist(r.end),
      ].join('\n');
    }

    test('T-0065-AC2 a hand edit inside a keep region survives regeneration byte for byte', () {
      final root = _root('keep');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      f.writeAsStringSync(editRegion(f.readAsStringSync()));
      expect(_lines(_gen(root).out), ['$_dir: no changes']);

      _setSpec(root, _specWithCount);
      final r = _gen(root);
      expect(r.code, 0, reason: '$r');
      expect(_lines(r.out), [
        '$_dir: wrote 2 file(s)',
        '  update $_greeting',
        '  write $_dir/.mcgen/manifest.json',
      ]);
      final text = f.readAsStringSync();
      expect(
        KeepScan.of(text, '//')['greeting.render']!.body.join('\n'),
        handBody,
      );
      expect(text, contains('    this.count = 0,\n'));
      expect(text, contains('  final int count;\n'));
      expect(_check(root).code, 0);
    });

    test('T-0065-AC2 a hand edit outside a keep region stops gen, names the file and writes nothing', () {
      final root = _root('drift');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      f.writeAsStringSync('${f.readAsStringSync()}// stray hand edit\n');
      _setSpec(
        root,
        _specWithCount.replaceFirst(
          'enum: [calm, cheerful]',
          'enum: [calm, cheerful, stern]',
        ),
      );
      final before = _module(root);
      final r = _gen(root);
      expect(r.code, 1);
      expect(r.out, '');
      expect(_lines(r.err), [
        'mcgen gen: refusing to write anything: 1 drifted file(s)',
        '  $_greeting: hand-edit: edited outside keep regions',
        'remedies: move the edit into a keep region or the spec, add the file to owned: (mixed modules), or pass --force',
      ]);
      expect(
        _module(root),
        before,
        reason: 'mood.dart and the manifest must not be written either',
      );
    });

    test('T-0065-AC2 --force overwrites a drifted file, keeps its regions, and logs it', () {
      final root = _root('force');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      f.writeAsStringSync(
        '${editRegion(f.readAsStringSync())}// stray hand edit\n',
      );
      final r = _gen(root, ['--force']);
      expect(r.code, 0);
      expect(_lines(r.out), [
        '$_dir: wrote 1 file(s)',
        '  update $_greeting (forced over hand-edit)',
      ]);
      final text = f.readAsStringSync();
      expect(text, isNot(contains('stray hand edit')));
      expect(
        KeepScan.of(text, '//')['greeting.render']!.body.join('\n'),
        handBody,
      );
      expect(
        contentHash('lib/src/greeting.dart', text),
        contentHash(
          'lib/src/greeting.dart',
          readFile(
            Directory(p.join(mcgenDir, _golden)),
            'lib/src/greeting.dart',
          ),
        ),
      );
    });

    test(
      'T-0065-AC2 a file mcgen never wrote is not overwritten without --force',
      () {
        final root = _root('unmanaged');
        writeFile(root, '$_dir/pubspec.yaml', 'name: mc_hello\n');
        final r = _gen(root);
        expect(r.code, 1);
        expect(
          _lines(r.err)[1],
          '  $_dir/pubspec.yaml: unmanaged: exists, but mcgen did not write it',
        );
        expect(readFile(root, '$_dir/pubspec.yaml'), 'name: mc_hello\n');
        expect(File(p.join(root.path, _greeting)).existsSync(), isFalse);
      },
    );

    test('T-0065-AC2 damaged keep markers stop gen', () {
      final root = _root('damage');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      f.writeAsStringSync(
        f.readAsStringSync().replaceFirst(
          '    // mcgen:end greeting.render\n',
          '',
        ),
      );
      final r = _gen(root);
      expect(r.code, 1);
      expect(_lines(r.err).sublist(1, 3), [
        '  $_greeting: hand-edit: edited outside keep regions',
        '  $_greeting: keep-damage: line 25: keep "greeting.render" is never closed',
      ]);
    });
  });

  group('T-0065-AC2 ownership modes', () {
    test('T-0065-AC2 mixed: an owned file is written once and never again', () {
      final spec = helloSpec
          .replaceFirst('ownership: managed', 'ownership: mixed')
          .replaceFirst(
            'keep: [greeting.render]',
            'keep: [greeting.render]\nowned: [lib/src/mood.dart]',
          );
      final root = _root('mixed', spec: spec);
      final first = _gen(root);
      expect(first.code, 0);
      expect(_lines(first.out), contains('  create $_dir/lib/src/mood.dart'));
      final mood = File(p.join(root.path, '$_dir/lib/src/mood.dart'));
      final generated = mood.readAsStringSync();
      expect(
        generated,
        startsWith('/// How a greeting sounds.\n'),
        reason: 'owned files carry no mcgen header',
      );
      final manifest = Manifest.decode(
        readFile(root, '$_dir/.mcgen/manifest.json'),
      );
      expect(manifest.ownership, 'mixed');
      expect(manifest.files['lib/src/mood.dart']!.ownership, 'owned');
      expect(
        manifest.files['lib/src/mood.dart']!.hash,
        contentHash('lib/src/mood.dart', generated),
      );

      const hand =
          '/// Hand-owned now.\nenum Mood { calm, cheerful, grumpy }\n';
      mood.writeAsStringSync(hand);
      _setSpec(
        root,
        spec.replaceFirst(
          'enum: [calm, cheerful]',
          'enum: [calm, cheerful, stern]',
        ),
      );
      final second = _gen(root);
      expect(second.code, 0, reason: '$second');
      // Only the manifest (its spec hash) changes; mood.dart is not written.
      expect(_lines(second.out), [
        '$_dir: wrote 1 file(s)',
        '  write $_dir/.mcgen/manifest.json',
      ]);
      expect(mood.readAsStringSync(), hand);
      final m2 = Manifest.decode(readFile(root, '$_dir/.mcgen/manifest.json'));
      expect(
        m2.files['lib/src/mood.dart']!.hash,
        contentHash('lib/src/mood.dart', generated),
        reason: 'the first-write hash stays',
      );
      expect(
        _check(root).code,
        0,
        reason: 'a hand-edited owned file is not drift',
      );

      mood.deleteSync();
      final third = _gen(root);
      expect(
        _lines(third.out).first,
        '$_dir: owned lib/src/mood.dart was deleted; not written again',
      );
      expect(mood.existsSync(), isFalse);
    });

    test('T-0065-AC2 ejected: nothing is written', () {
      final root = _root(
        'ejected',
        spec: helloSpec.replaceFirst(
          'ownership: managed',
          'ownership: ejected',
        ),
      );
      final r = _gen(root);
      expect(r.code, 0);
      expect(_lines(r.out), ['$_dir: ejected: nothing written']);
      expect(snapshot(p.join(root.path, _dir)).keys, ['mcgen.yaml']);
      expect(_gen(root, ['--check']).code, 0);
      expect(_check(root).code, 0);
    });
  });

  group('T-0065-AC2 mcgen check reports each drift kind', () {
    test('T-0065-AC2 a clean module passes', () {
      final root = _root('check-clean');
      expect(_gen(root).code, 0);
      final r = _check(root);
      expect(r.code, 0);
      expect(r.err, '');
      expect(_lines(r.out), ['mcgen check: 1 module(s), 0 drift, 0 error(s)']);
    });

    test('T-0065-AC2 hand-edit', () {
      final root = _root('check-hand');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      f.writeAsStringSync(
        f.readAsStringSync().replaceFirst(
          'final bool excited;',
          'final bool excited; // hand',
        ),
      );
      final r = _check(root);
      expect(r.code, 1);
      expect(_lines(r.err), [
        '$_greeting: hand-edit: edited outside keep regions',
      ]);
      expect(_lines(r.out), ['mcgen check: 1 module(s), 1 drift, 0 error(s)']);
    });

    test('T-0065-AC2 stale-manifest: the spec changed, or the module was never generated', () {
      final root = _root('check-stale');
      final never = _check(root);
      expect(_lines(never.err), [
        '$_dir/.mcgen/manifest.json: stale-manifest: missing: the module was never generated (run mcgen gen)',
      ]);
      expect(_gen(root).code, 0);
      _setSpec(root, _specWithCount);
      final r = _check(root);
      expect(r.code, 1);
      expect(_lines(r.err), [
        '$_dir/.mcgen/manifest.json: stale-manifest: the spec changed since the last gen',
        '$_greeting: stale-manifest: out of date: gen would update it',
      ]);
    });

    test('T-0065-AC2 keep-damage: an end marker removed, a region removed', () {
      final root = _root('check-keep');
      expect(_gen(root).code, 0);
      final f = File(p.join(root.path, _greeting));
      final good = f.readAsStringSync();
      f.writeAsStringSync(
        good.replaceFirst('    // mcgen:end greeting.render\n', ''),
      );
      expect(_lines(_check(root).err), [
        '$_greeting: hand-edit: edited outside keep regions',
        '$_greeting: keep-damage: line 25: keep "greeting.render" is never closed',
      ]);
      f.writeAsStringSync(
        good
            .replaceFirst('    // mcgen:keep greeting.render\n', '')
            .replaceFirst('    // mcgen:end greeting.render\n', ''),
      );
      expect(_lines(_check(root).err), [
        '$_greeting: hand-edit: edited outside keep regions',
        '$_greeting: keep-damage: keep region "greeting.render" was removed',
      ]);
    });
  });

  group('T-0065-AC2 tool/loc agrees with the manifest', () {
    test(
      'T-0065-AC2 keep-region lines count as hand, the rest as scaffold',
      () {
        final loc = p.join(repoRoot, 'tool', 'loc');
        if (!File(p.join(loc, '.dart_tool', 'package_config.json'))
            .existsSync()) {
          final get = Process.runSync(Platform.resolvedExecutable, [
            'pub',
            'get',
            '--offline',
          ], workingDirectory: loc);
          expect(get.exitCode, 0, reason: '${get.stderr}');
        }
        final root = _root('loc');
        expect(_gen(root).code, 0);
        Map<String, Object?> count() {
          final out = p.join(root.path, 'loc.json');
          final r = Process.runSync(
            Platform.resolvedExecutable,
            ['run', p.join(loc, 'bin', 'loc.dart'), root.path, '--json', out],
            workingDirectory: loc,
          );
          expect(r.exitCode, 0, reason: '${r.stderr}');
          final j =
              jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>;
          File(out).deleteSync();
          return (j['totals']! as Map<String, Object?>)['source']!
              as Map<String, Object?>;
        }

        // lib/: barrel 2, mood 1, greeting 16 code lines; 1 of them in the keep region.
        expect(count(), {'hand': 1, 'scaffold': 18});
        final f = File(p.join(root.path, _greeting));
        f.writeAsStringSync(
          f.readAsStringSync().replaceFirst(
            "    return 'Welcome,",
            "    final x = 1;\n    return 'Welcome,",
          ),
        );
        expect(count(), {
          'hand': 2,
          'scaffold': 18,
        }, reason: 'a keep-region edit stays scaffold outside it');
        f.writeAsStringSync(
          f.readAsStringSync().replaceFirst(
            'final bool excited;',
            'final bool excited; // hand',
          ),
        );
        expect(count(), {
          'hand': 17,
          'scaffold': 3,
        }, reason: 'drift outside a region makes the file hand');
      },
    );
  });
}
