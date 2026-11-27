// T-0065-AC3 (determinism), part 2: the real executable, run from two
// working directories with different environments, writes the same bytes,
// and no output carries an absolute path.

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/utility_hello/utility_hello.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

/// Runs bin/mcgen.dart in a separate VM from [cwd].
ProcessResult _run(List<String> args, String cwd, Map<String, String> env) =>
    Process.runSync(
      Platform.resolvedExecutable,
      [
        '--packages=${p.join(mcgenDir, '.dart_tool', 'package_config.json')}',
        p.join(mcgenDir, 'bin', 'mcgen.dart'),
        ...args,
      ],
      workingDirectory: cwd,
      environment: env,
    );

void main() {
  test('T-0065-AC3 same seed, two working directories and environments: identical bytes, no absolute paths', () {
    final a = helloRoot('cwd-a');
    final b = helloRoot('cwd-bb');
    addTearDown(() {
      a.deleteSync(recursive: true);
      b.deleteSync(recursive: true);
    });
    // Root found from the working directory (the module dir, via --root .. /
    // relative target) in one, and an explicit absolute --root in the other.
    final ra = _run(
      ['gen', '--root', '../..', 'mc_hello'],
      p.join(a.path, 'utility', 'mc_hello'),
      {
        'TZ': 'Pacific/Kiritimati',
        'LANG': 'ja_JP.UTF-8',
        'LC_ALL': 'ja_JP.UTF-8',
      },
    );
    final rb = _run(
      ['gen', '--root', b.path, 'utility/mc_hello'],
      b.path,
      {'TZ': 'UTC', 'LANG': 'C', 'LC_ALL': 'C'},
    );
    expect(ra.exitCode, 0, reason: '${ra.stdout}${ra.stderr}');
    expect(rb.exitCode, 0, reason: '${rb.stdout}${rb.stderr}');
    expect(ra.stdout, rb.stdout, reason: 'reports are root-relative too');

    final ta = snapshot(p.join(a.path, 'utility', 'mc_hello'));
    final tb = snapshot(p.join(b.path, 'utility', 'mc_hello'));
    expect(tb, ta);
    expect(ta.length, 6);
    final forbidden = [
      a.path,
      b.path,
      mcgenDir,
      repoRoot,
      Directory.systemTemp.resolveSymbolicLinksSync(),
      ?Platform.environment['HOME'],
      ?Platform.environment['USER'],
    ];
    ta.forEach((path, content) {
      for (final f in forbidden) {
        expect(content.contains(f), isFalse, reason: '$path contains "$f"');
      }
      expect(content.contains('\r'), isFalse, reason: '$path has CR');
      expect(content.endsWith('\n'), isTrue, reason: '$path has a final LF');
    });
    // The manifest keys and file lists are sorted by code unit.
    final m = Manifest.decode(ta['.mcgen/manifest.json']!);
    expect(m.files.keys.toList(), [...m.files.keys]..sort());
    expect(m.seed, '0x562a6946d495a023');
  });

  test('T-0065-AC3 a different seed salt re-rolls the seeded choice, and only that', () {
    String pickFor(int salt) =>
        salutations[Rng.forModule(
          globalSeed: 20261127,
          module: 'mc_hello',
          seedSalt: salt,
        ).fork('entities').fork('Greeting').nextInt(salutations.length)];
    expect(pickFor(0), 'Welcome');
    final salt = [for (var s = 1; s < 50; s++) s]
        .firstWhere((s) => pickFor(s) != 'Welcome');
    final a = helloRoot('salt-0');
    final b = helloRoot(
      'salt-$salt',
      spec: helloSpec.replaceFirst('seed_salt: 0', 'seed_salt: $salt'),
    );
    addTearDown(() {
      a.deleteSync(recursive: true);
      b.deleteSync(recursive: true);
    });
    expect(mcgen(['gen', '--root', a.path, 'mc_hello']).code, 0);
    expect(mcgen(['gen', '--root', b.path, 'mc_hello']).code, 0);
    final ta = snapshot(p.join(a.path, 'utility', 'mc_hello'));
    final tb = snapshot(p.join(b.path, 'utility', 'mc_hello'));
    final differ = [
      for (final k in ta.keys)
        if (ta[k] != tb[k]) k,
    ];
    expect(differ, [
      '.mcgen/manifest.json',
      'lib/src/greeting.dart',
      'mcgen.yaml',
    ]);
    expect(ta['lib/src/greeting.dart'], contains("return 'Welcome, Greeting("));
    expect(
      tb['lib/src/greeting.dart'],
      contains("return '${pickFor(salt)}, Greeting("),
    );
  });
}
