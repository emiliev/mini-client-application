// T-0069: the list-detail archetype (P2-04). Its exemplar,
// feature/characters/characters_list, is its golden: the render must equal
// it outside keep regions and owned files (plan 02 KD1, ADR-0017). A second,
// throwaway LD spec proves the templates are not the exemplar with names
// swapped (tool/T-0069-AC3_ld_probe.sh runs it under Bazel too).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/common/barrel_scan.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _exemplarRel = 'feature/characters/characters_list';
final String _exemplar = p.join(repoRoot, _exemplarRel);

/// A temp root holding a copy of the exemplar and every utility pubspec (so
/// the package catalog knows the first-party deps), with [edit] applied to
/// the spec.
Directory _copyRoot(String tag, {String Function(String spec)? edit}) {
  final root = tempRoot(tag);
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
  for (final rel in listTree(_exemplar)) {
    final bytes = File(p.join(_exemplar, rel)).readAsBytesSync();
    final f = File(p.join(root.path, _exemplarRel, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
  }
  if (edit != null) {
    final spec = File(p.join(root.path, _exemplarRel, 'mcgen.yaml'));
    final before = spec.readAsStringSync();
    final after = edit(before);
    expect(after, isNot(before), reason: 'the edit changed the spec');
    spec.writeAsStringSync(after);
  }
  return root;
}

Generator get _generator {
  final tool = ToolLayout(mcgenDir);
  final cfg = tool.loadConfig();
  return Generator(
    config: cfg,
    archetypes: archetypes,
    bricks: BrickSet(tool.bricksDir),
    formatter: DartFormatter(cfg),
  );
}

GeneratedModule _render(String root, String specRel) => _generator.generate(
  loadSpec(
    text: File(p.join(root, specRel)).readAsStringSync(),
    file: specRel,
    schema: schema,
  ),
  index: RepoIndex.scan(root),
  forbidden: [root, mcgenDir],
);

/// The probe spec in a temp root at feature/zz_probe/zz_ld_probe.
Directory _probeRoot(String tag) {
  final root = tempRoot(tag);
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
  writeFile(
    root,
    'feature/zz_probe/zz_ld_probe/mcgen.yaml',
    readFixture('zz_ld_probe/mcgen.yaml'),
  );
  return root;
}

void main() {
  group('T-0069-AC1 the exemplar round-trips', () {
    test('T-0069-AC1 mcgen gen characters_list --check exits 0 against the '
        'merged exemplar', () {
      final r = mcgen(['gen', '--check', 'characters_list'], cwd: repoRoot);
      expect(r.code, 0, reason: '$r');
      expect(r.out, contains('$_exemplarRel: up to date'));
      final c = mcgen(['check', 'characters_list'], cwd: repoRoot);
      expect(c.code, 0, reason: '$c');
    });

    test('T-0069-AC1 the round-trip golden: compareToExemplar finds the render '
        'identical to the real exemplar', () {
      final gen = _render(repoRoot, '$_exemplarRel/mcgen.yaml');
      final diff = compareToExemplar(gen, _exemplar);
      expect(diff.identical, isTrue, reason: '$diff');
      // Every exemplar file is rendered except the owned ones mcgen never
      // writes (the legacy goldens); the owned files it does write (env,
      // contract test) are only checked to exist.
      final owned = {
        for (final f in gen.files.values)
          if (f.ownership == 'owned') f.path,
      };
      expect(owned, {
        'test/contract/characters_api_contract_test.dart',
        'test/feature/util/characters_list_env.dart',
      });
      final compared = gen.files.length - owned.length;
      // 56 until T-0074 moved BUILD.bazel to `mcgen buildgen` and the
      // root-import list to `mcgen wire` (P-126); their own tests check them.
      expect(compared, 54);
      expect(gen.files.keys, isNot(contains('BUILD.bazel')));
      expect(gen.files.keys, isNot(contains('lib/src/di/flow_scope.dart')));
      expect(gen.files.keys, contains('lib/src/l10n/characters_list_de.arb'));
      expect(
        gen.files.keys,
        contains('test/feature/characters_list_related_comics.feature'),
      );
    });

    test('T-0069-AC1 a changed entity field makes --check exit 1 and name '
        'the file', () {
      final root = _copyRoot(
        'field',
        edit: (s) => s.replaceFirst(
          '{name: description, type: String}',
          '{name: summary, type: String}',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains(
          '$_exemplarRel/lib/src/domain/model/character_dto.dart: round-trip: '
          'line 17:     required String summary, |     required String description,',
        ),
      );
      expect(
        RegExp('round-trip').allMatches(r.err),
        hasLength(1),
        reason: 'only the DTO file changes: ${r.err}',
      );
    });

    test('T-0069-AC1 a changed ARB string makes --check exit 1 and name the '
        'file', () {
      final root = _copyRoot(
        'arb',
        edit: (s) => s.replaceFirst('de: Figuren,', 'de: Helden,'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains(
          '$_exemplarRel/lib/src/l10n/characters_list_de.arb: round-trip: '
          'line 3:   "charactersListTitle": "Helden", |   "charactersListTitle": "Figuren",',
        ),
      );
    });

    test('T-0069-AC1 an edit inside a keep region keeps --check green; an '
        'edit outside one fails it', () {
      final root = _copyRoot('keep');
      addTearDown(() => root.deleteSync(recursive: true));
      final bloc = File(
        p.join(
          root.path,
          _exemplarRel,
          'lib/src/presentation/bloc/character_preview_bloc.dart',
        ),
      );
      final original = bloc.readAsStringSync();
      bloc.writeAsStringSync(
        original.replaceFirst(
          '          _navigator.openCharacter(state.id);\n',
          '          // A hand-written handler.\n'
              '          _navigator.openCharacter(state.id);\n',
        ),
      );
      final inside = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(inside.code, 0, reason: '$inside');

      bloc.writeAsStringSync(
        original.replaceFirst(
          'final CharactersListNavigator _navigator;',
          'final CharactersListNavigator _navigator; // edited',
        ),
      );
      final outside = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_list',
      ]);
      expect(outside.code, 1, reason: '$outside');
      expect(
        outside.err,
        contains(
          '$_exemplarRel/lib/src/presentation/bloc/character_preview_bloc.dart: round-trip',
        ),
      );
    });

    test('T-0069-AC1 gen writes only the manifest into an exemplar, and the '
        'committed manifest is the one it writes', () {
      final root = _copyRoot('manifest');
      addTearDown(() => root.deleteSync(recursive: true));
      final dir = p.join(root.path, _exemplarRel);
      final before = hashTree(dir);
      final committed = File(
        p.join(dir, '.mcgen/manifest.json'),
      ).readAsStringSync();
      File(p.join(dir, '.mcgen/manifest.json')).deleteSync();
      final r = mcgen(['gen', '--root', root.path, 'characters_list']);
      expect(r.code, 0, reason: '$r');
      expect(r.out, contains('write $_exemplarRel/.mcgen/manifest.json'));
      expect(hashTree(dir), before, reason: 'only the manifest, unchanged');
      final manifest = Manifest.decode(committed);
      expect(manifest.ownership, 'ejected');
      expect(
        manifest
            .files['lib/src/presentation/bloc/related_comics_bloc.dart']!
            .keep
            .keys,
        [
          'section.RelatedComics.open',
        ],
      );
      expect(
        manifest.files['test/feature/util/characters_list_env.dart']!.ownership,
        'owned',
      );
    });
  });

  group('T-0069-AC3 a second list-detail module', () {
    test('T-0069-AC3 the probe spec lints clean and renders the same bytes '
        'in two roots', () {
      final a = _probeRoot('probe-a');
      final b = _probeRoot('probe-b');
      addTearDown(() {
        a.deleteSync(recursive: true);
        b.deleteSync(recursive: true);
      });
      final lint = mcgen(['spec', 'lint', '--root', a.path, 'zz_ld_probe']);
      expect(lint.code, 0, reason: '$lint');
      const spec = 'feature/zz_probe/zz_ld_probe/mcgen.yaml';
      final ga = _render(a.path, spec);
      final gb = _render(b.path, spec);
      expect(
        {for (final f in ga.files.values) f.path: f.content},
        {for (final f in gb.files.values) f.path: f.content},
      );
      expect(ga.manifest.encode(), gb.manifest.encode());
    });

    test('T-0069-AC3 the probe is its own module, not the exemplar with '
        'names swapped', () {
      final root = _probeRoot('probe-names');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, 'feature/zz_probe/zz_ld_probe/mcgen.yaml');
      final paths = gen.files.keys.toSet();
      expect(
        paths,
        containsAll([
          'lib/src/domain/model/comic.dart',
          'lib/src/domain/model/comic_dto.dart',
          'lib/src/domain/model/comics_query.dart',
          'lib/src/presentation/page/comic_preview_page.dart',
          'test/feature/step/i_see_the_comic_preview_for.dart',
          'test/feature/step/the_app_was_asked_to_open_comic.dart',
          'test/feature/zz_ld_probe_empty.feature',
        ]),
      );
      // No section: no section bloc, widget or step; no filter: no flow key.
      expect(paths.where((f) => f.contains('related')), isEmpty);
      expect(
        paths,
        isNot(
          contains('test/feature/step/i_scroll_the_preview_until_i_see.dart'),
        ),
      );
      expect(
        gen.files['lib/src/flow/zz_ld_probe_flow.dart']!.content,
        isNot(contains('ValueKey(initial')),
      );
      // Nothing of the exemplar's vocabulary leaks into the probe.
      for (final f in gen.files.values) {
        expect(
          f.content.toLowerCase(),
          isNot(contains('character')),
          reason: '${f.path} mentions the exemplar',
        );
        expect(f.content, isNot(contains('T-0032')), reason: f.path);
      }
      // A managed module gets the header; the pseudo-locale is computed.
      expect(
        gen.files['lib/src/presentation/bloc/zz_ld_probe_bloc.dart']!.content,
        startsWith('// Scaffolded by mcgen'),
      );
      expect(
        gen.files['lib/src/l10n/zz_ld_probe_en_XA.arb']!.content,
        contains('"zzLdProbeTitle": "[Çóɱíçš ~~~]"'),
      );
      expect(
        gen.files['test/feature/zz_ld_probe.feature']!.content,
        contains('  @MC-zz_ld_probe-01\n  Scenario: The first page lists 20'),
      );
    });

    test('T-0069-AC3 a step no template knows is written once, as a failing '
        'stub', () {
      final root = _probeRoot('probe-stub');
      addTearDown(() => root.deleteSync(recursive: true));
      final spec = File(
        p.join(root.path, 'feature/zz_probe/zz_ld_probe/mcgen.yaml'),
      );
      spec.writeAsStringSync(
        spec.readAsStringSync().replaceFirst(
          "          - \"Then I see {'No comics yet'}\"\n",
          "          - \"Then I see {'No comics yet'}\"\n"
              "          - And the shelf holds {3} boxes of {'tea'}\n",
        ),
      );
      final gen = _render(root.path, 'feature/zz_probe/zz_ld_probe/mcgen.yaml');
      final stub =
          gen.files['test/feature/step/the_shelf_holds_boxes_of.dart']!;
      expect(stub.ownership, 'owned');
      expect(
        stub.content,
        contains(
          'Future<void> theShelfHoldsBoxesOf(\n'
          '  WidgetTester tester,\n'
          '  int p1,\n'
          '  String p2,\n'
          ') async {',
        ),
      );
      expect(
        stub.content,
        contains("fail('step \"theShelfHoldsBoxesOf\" is not written yet');"),
      );
    });

    test('T-0069-AC3 list_detail\'s lint names what a spec gets wrong', () {
      List<String> lintWith(String Function(String) edit) {
        final root = _probeRoot('probe-lint');
        addTearDown(() => root.deleteSync(recursive: true));
        final spec = File(
          p.join(root.path, 'feature/zz_probe/zz_ld_probe/mcgen.yaml'),
        );
        spec.writeAsStringSync(edit(spec.readAsStringSync()));
        final r = mcgen(['spec', 'lint', '--root', root.path, 'zz_ld_probe']);
        expect(r.code, 1, reason: '$r');
        return [
          for (final l in r.err.trim().split('\n'))
            l.substring(l.indexOf('error')),
        ];
      }

      expect(
        lintWith(
          (s) => s.replaceFirst('    title: title\n', '    title: headline\n'),
        ),
        [
          'error [list_detail] options.list.title: "Comic" has no field "headline"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst('options:\n', 'options:\n  colour: red\n'),
        ),
        ['error [list_detail] options.colour: unknown key "colour"'],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst(
            '    - key: zzLdProbeEmptyTitle\n'
                '      description: Title of the empty list.\n'
                '      text: {en: No comics yet, de: Noch keine Comics}\n',
            '',
          ),
        ),
        [
          'error [list_detail] l10n.strings: list_detail needs the string "zzLdProbeEmptyTitle"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst('calls: openComic', 'calls: openSeries'),
        ),
        [
          'error [list_detail] options.preview.actions[0].calls: the navigator has no method "openSeries"',
        ],
      );
    });

    test('T-0069-AC3 a prose slot no template uses fails gen, naming it', () {
      final root = _probeRoot('probe-prose');
      addTearDown(() => root.deleteSync(recursive: true));
      final spec = File(
        p.join(root.path, 'feature/zz_probe/zz_ld_probe/mcgen.yaml'),
      );
      spec.writeAsStringSync(
        '${spec.readAsStringSync()}  prose:\n    flow.dco: A typo.\n',
      );
      final r = mcgen(['gen', '--check', '--root', root.path, 'zz_ld_probe']);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('options.prose has slot(s) no template uses: flow.dco'),
      );
    });

    test('T-0069-AC3 the shared-step table is mc_test_steps\' barrel', () {
      final barrel = p.join(
        repoRoot,
        'utility/mc_test_steps/lib/mc_test_steps.dart',
      );
      final steps = {
        for (final m in RegExp(r"src/[a-z_]+/([a-z_]+)\.dart'").allMatches(
          File(barrel).readAsStringSync(),
        ))
          m[1]!,
      };
      expect(sharedSteps, steps);
      expect(exportedNames(barrel, repoRoot), contains('theBackendServes'));
      expect(
        stepFileName("I don't see the character preview"),
        'i_dont_see_the_character_preview',
      );
      expect(
        stepFileName('Given the pseudo-locale is active'),
        'the_pseudolocale_is_active',
      );
      expect(
        stepFunctionName("And I tap {'A'} and {'B'} in quick succession"),
        'iTapAndInQuickSuccession',
      );
    });
  });
}
