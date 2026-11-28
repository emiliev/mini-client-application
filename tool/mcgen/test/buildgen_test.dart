// T-0074: `mcgen buildgen` (plan 02 section 2.8, ADR-0018). Every feature
// BUILD file regenerates byte for byte from its package's files; what the
// files cannot explain is a `# keep` item or the hand region, and nothing
// else survives a regeneration.

import 'dart:io';

import 'package:mcgen/src/buildgen/adopt.dart';
import 'package:mcgen/src/buildgen/buildgen.dart';
import 'package:mcgen/src/buildgen/starlark.dart';
import 'package:mcgen/src/core/roundtrip.dart' show listTree;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _feature = 'feature/characters/characters_list';

/// A temp root holding [features] (copied from the repo, lib/, test/ and
/// their package files) and every utility pubspec, so labels resolve.
Directory _root(String tag, {List<String> features = const [_feature]}) {
  final root = tempRoot('T-0074-$tag');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final d in Directory(p.join(repoRoot, 'utility')).listSync()) {
    final pubspec = File(p.join(d.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      writeFile(
        root,
        'utility/${p.basename(d.path)}/pubspec.yaml',
        pubspec.readAsStringSync(),
      );
    }
  }
  for (final f in features) {
    for (final rel in listTree(p.join(repoRoot, f))) {
      if (rel.startsWith('.dart_tool/')) continue;
      File(p.join(root.path, f, rel))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(File(p.join(repoRoot, f, rel)).readAsBytesSync());
    }
  }
  return root;
}

String _build(Directory root, [String f = _feature]) =>
    readFile(root, '$f/BUILD.bazel');

void main() {
  group('T-0074-AC1 buildgen agrees with every feature BUILD file', () {
    test('T-0074-AC1 buildgen --check exits 0 on the repo: every feature '
        'BUILD file is up to date', () {
      final r = mcgen(['buildgen', '--check'], cwd: repoRoot);
      expect(r.code, 0, reason: '$r');
      final features = [
        for (final d in Directory(p.join(repoRoot, 'feature')).listSync())
          if (d is Directory)
            for (final m in d.listSync())
              if (File(p.join(m.path, 'BUILD.bazel')).existsSync())
                p.relative(m.path, from: repoRoot),
      ];
      expect(features, hasLength(greaterThanOrEqualTo(11)));
      for (final f in features) {
        expect(r.out, contains('$f/BUILD.bazel: up to date'));
      }
    });

    test('T-0074-AC1 utility packages are not covered: no archetype covers '
        'one, so buildgen writes no utility BUILD file', () {
      final outputs = buildAll(repoRoot);
      expect(
        outputs.where((o) => o.path.startsWith('utility/')),
        isEmpty,
      );
      expect(
        outputs.map((o) => o.path),
        everyElement(startsWith('feature/')),
        reason: 'and no hand-written app or wiring BUILD file (F-0074)',
      );
    });

    test('T-0074-AC1 a dep the imports need and the BUILD file lacks fails '
        '--check, naming the file and line', () {
      final root = _root('missing-dep');
      final f = File(p.join(root.path, _feature, 'BUILD.bazel'));
      f.writeAsStringSync(
        f.readAsStringSync().replaceFirst(
          '    "//utility/mc_paging",\n',
          '',
        ),
      );
      final r = mcgen(['buildgen', '--check', '--root', root.path]);
      expect(r.code, 1, reason: '$r');
      expect(r.err, contains('$_feature/BUILD.bazel: out of date, line'));
      expect(r.err, contains('//utility/mc_paging'));
    });

    test('T-0074-AC1 an import the BUILD file does not know about is added '
        'by a regeneration', () {
      final root = _root('new-import');
      final bloc = File(
        p.join(
          root.path,
          _feature,
          'lib/src/presentation/bloc/characters_list_bloc.dart',
        ),
      );
      bloc.writeAsStringSync(
        "import 'package:mc_formatters/mc_formatters.dart';\n"
        '${bloc.readAsStringSync()}',
      );
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      final pure = RegExp(
        r'_PURE_DEPS = \[\n((?:    .*\n)+)\]',
      ).firstMatch(_build(root))!.group(1)!;
      expect(pure, contains('"//utility/mc_formatters",'));
      expect(mcgen(['buildgen', '--check', '--root', root.path]).code, 0);
    });

    test('T-0074-AC1 a # keep item survives a regeneration; an unkept item '
        'the imports do not explain is dropped', () {
      final root = _root('keep');
      final f = File(p.join(root.path, _feature, 'BUILD.bazel'));
      final kept = f.readAsStringSync();
      expect(kept, contains('    "//utility/mc_ds_theme",  # keep\n'));
      f.writeAsStringSync(
        kept.replaceFirst(
          '    "//utility/mc_ds_theme",  # keep\n',
          '    "//utility/mc_ds_theme",\n',
        ),
      );
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      expect(_build(root), isNot(contains('"//utility/mc_ds_theme"')));

      f.writeAsStringSync(kept);
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      expect(_build(root), kept);
    });

    test('T-0074-AC1 comments above a statement and inside an unchanged one '
        'are prose: kept; a statement whose code changed is rewritten', () {
      final root = _root('prose');
      final f = File(p.join(root.path, _feature, 'BUILD.bazel'));
      final before = f.readAsStringSync();
      f.writeAsStringSync(
        before
            .replaceFirst(
              '# Generator input only (V3-18)',
              '# My own words about _stage.\n# Generator input only (V3-18)',
            )
            .replaceFirst('    size = "small",\n', '    size = "large",\n'),
      );
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      final after = _build(root);
      expect(after, contains('# My own words about _stage.\n'));
      expect(after, isNot(contains('size = "large"')));
      expect(
        after.replaceFirst('# My own words about _stage.\n', ''),
        before,
      );
    });

    test('T-0074-AC1 a statement in the hand region replaces the generated '
        'one of the same key, and a hand target is kept', () {
      final root = _root('hand');
      final f = File(p.join(root.path, _feature, 'BUILD.bazel'));
      final before = f.readAsStringSync();
      final arch = RegExp(
        r'\ndart_test\(\n    name = "architecture_test",[\s\S]*?\n\)\n',
      ).firstMatch(before)!.group(0)!;
      final medium = arch.replaceFirst('"small"', '"medium"');
      f.writeAsStringSync(
        '${before.replaceFirst(arch, '\n')}\n'
        '$handRegionStart\n'
        '${medium.trim()}\n'
        '\n'
        'filegroup(\n    name = "extra",\n    srcs = ["README.md"],\n)\n'
        '$handRegionEnd\n',
      );
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      final after = _build(root);
      expect(
        RegExp('name = "architecture_test"').allMatches(after),
        hasLength(1),
      );
      expect(after, contains('size = "medium"'));
      expect(after, contains('name = "extra"'));
      expect(mcgen(['buildgen', '--check', '--root', root.path]).code, 0);
    });

    test('T-0074-AC1 the hand region must end the file and be the only '
        'region', () {
      expect(
        () =>
            BuildFile.parse('$handRegionStart\nx = 1\n$handRegionEnd\ny = 2\n'),
        throwsFormatException,
      );
      expect(
        () => BuildFile.parse('# mcgen:keep other\nx = 1\n# mcgen:end other\n'),
        throwsFormatException,
      );
      expect(
        () => BuildFile.parse('$handRegionStart\nx = 1\n'),
        throwsFormatException,
      );
    });

    test('T-0074-AC1 the Starlark reader: keys, code without comments, '
        '# keep items and order-free comparison', () {
      final f = BuildFile.parse(
        '# header\n'
        'load("//a:b.bzl", "x")\n'
        '\n'
        '_DEPS = [\n'
        '    "b",  # keep\n'
        '    "a",\n'
        ']\n'
        '\n'
        '# about t\n'
        'x(\n    name = "t",\n    deps = _DEPS + ["c"],  # trailing\n)\n',
      );
      expect(
        [for (final s in f.statements) s.key],
        [
          'load://a:b.bzl',
          'var:_DEPS',
          'rule:t',
        ],
      );
      expect(f.statements.first.lead, '# header\n');
      expect(f.statements.last.lead, '\n# about t\n');
      expect(f['var:_DEPS']!.kept, {
        '_DEPS': {'b'},
      });
      final sorted = BuildFile.parse('_DEPS = [\n    "a",\n    "b",\n]\n');
      expect(f['var:_DEPS']!.sameCode(sorted.statements.single), isFalse);
      expect(
        f['var:_DEPS']!.unorderedCode,
        sorted.statements.single.unorderedCode,
      );
    });

    test('T-0074-AC1 adopt marks unexplained items # keep and moves unknown '
        'statements into the hand region, so the file builds the same', () {
      final root = _root('adopt');
      final f = File(p.join(root.path, _feature, 'BUILD.bazel'));
      final canonical = f.readAsStringSync();
      // A hand-written file: no keep marks, an extra target, a list unsorted.
      final hand =
          '${canonical.replaceAll('  # keep', '').replaceFirst('    "//utility/mc_api_client",\n    "//utility/mc_api_errors",\n', '    "//utility/mc_api_errors",\n    "//utility/mc_api_client",\n')}'
          '\nfilegroup(\n    name = "notes",\n    srcs = ["NOTES.md"],\n)\n';
      f.writeAsStringSync(hand);
      final r = mcgen(['buildgen', '--adopt', '--root', root.path]);
      expect(r.code, 0, reason: '$r');
      final adopted = _build(root);
      expect(adopted, contains('"//utility/mc_ds_theme",  # keep'));
      expect(
        adopted,
        contains('$handRegionStart\nfilegroup(\n    name = "notes",'),
      );
      // Every statement of the hand file is there, with the same code up to
      // the order of list items.
      final a = BuildFile.parse(adopted);
      final all = [...a.statements, ...a.handStatements];
      for (final s in BuildFile.parse(hand).statements) {
        final t = all.firstWhere((x) => x.key == s.key);
        expect(t.unorderedCode, s.unorderedCode, reason: s.key);
      }
      expect(mcgen(['buildgen', '--check', '--root', root.path]).code, 0);
      expect(adoptBuild(adopted, (_) => adopted), adopted);
    });

    test('T-0074-AC1 a new feature gets a full BUILD file with the default '
        'header, and regenerates to itself', () {
      final root = _root('new');
      File(p.join(root.path, _feature, 'BUILD.bazel')).deleteSync();
      expect(mcgen(['buildgen', '--root', root.path]).code, 0);
      final b = _build(root);
      expect(b, startsWith('# characters_list: a feature package.'));
      expect(b, contains('mc_bdd_tests(\n    name = "bdd_test",'));
      expect(b, isNot(contains('\n$handRegionStart\n')));
      expect(mcgen(['buildgen', '--check', '--root', root.path]).code, 0);
    });
  });
}
