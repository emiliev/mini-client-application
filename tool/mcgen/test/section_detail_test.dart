// T-0072: the section-detail archetype (P2-05). Its two exemplars,
// feature/comics/comics_details and feature/characters/characters_details,
// are its golden: each render must equal its package outside keep regions and
// owned files (plan 02 KD1, ADR-0017). A third, throwaway SC spec proves the
// templates are not the exemplars with names swapped
// (tool/T-0072-AC3_sc_probe.sh runs it under Bazel too).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/common/bdd.dart';
import 'package:mcgen/src/emit/feature_section_detail/common.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _comics = 'feature/comics/comics_details';
const _characters = 'feature/characters/characters_details';

/// A temp root holding a copy of the exemplar at [rel] and every utility
/// pubspec (so the package catalog knows the first-party deps), with [edit]
/// applied to the spec.
Directory _copyRoot(
  String tag,
  String rel, {
  String Function(String spec)? edit,
}) {
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
  for (final f in listTree(p.join(repoRoot, rel))) {
    final bytes = File(p.join(repoRoot, rel, f)).readAsBytesSync();
    final out = File(p.join(root.path, rel, f));
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  }
  if (edit != null) {
    final spec = File(p.join(root.path, rel, 'mcgen.yaml'));
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
    schema: SpecSchema.load(p.join(mcgenDir, 'schema', 'mcgen-1.json')),
  ),
  index: RepoIndex.scan(root),
  forbidden: [root, mcgenDir],
);

const _probeSpec = 'feature/zz_probe/zz_sc_probe/mcgen.yaml';

/// The probe spec in a temp root at feature/zz_probe/zz_sc_probe.
Directory _probeRoot(String tag, {String Function(String)? edit}) {
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
  final text = readFixture('zz_sc_probe/mcgen.yaml');
  writeFile(root, _probeSpec, edit == null ? text : edit(text));
  return root;
}

void main() {
  for (final (name, rel, owned, compared) in [
    (
      'comics_details',
      _comics,
      {
        'lib/src/domain/model/comic.dart',
        'lib/src/domain/model/comic_dto.dart',
        'lib/src/domain/model/comic_mapper.dart',
        'lib/src/presentation/page/comic_details_page.dart',
        'lib/src/presentation/page/comic_cover_page.dart',
        'test/feature/util/comics_details_env.dart',
        'test/flow_scope_test.dart',
      },
      48, // 50 until T-0074 moved BUILD.bazel and flow_scope.dart out
    ),
    (
      'characters_details',
      _characters,
      {
        'lib/src/domain/model/character.dart',
        'lib/src/domain/model/character_dto.dart',
        'lib/src/domain/model/character_mapper.dart',
        'lib/src/presentation/page/character_details_page.dart',
        'test/feature/util/characters_details_env.dart',
        'test/flow_scope_test.dart',
      },
      49, // 51 until T-0074 moved BUILD.bazel and flow_scope.dart out
    ),
  ]) {
    group('T-0072-AC1 $name round-trips', () {
      test('T-0072-AC1 mcgen gen $name --check exits 0 against the merged '
          'exemplar', () {
        final r = mcgen(['gen', '--check', name], cwd: repoRoot);
        expect(r.code, 0, reason: '$r');
        expect(r.out, contains('$rel: up to date'));
        final c = mcgen(['check', name], cwd: repoRoot);
        expect(c.code, 0, reason: '$c');
      });

      test('T-0072-AC1 $name: compareToExemplar finds the render identical '
          'to the real exemplar', () {
        final gen = _render(repoRoot, '$rel/mcgen.yaml');
        final diff = compareToExemplar(gen, p.join(repoRoot, rel));
        expect(diff.identical, isTrue, reason: '$diff');
        // The files mcgen writes once and a human owns afterwards (and the
        // step stubs for steps about this page's own sections) are only
        // checked to exist.
        final ownedFiles = {
          for (final f in gen.files.values)
            if (f.ownership == 'owned') f.path,
        };
        expect(ownedFiles, containsAll(owned));
        expect(gen.files.keys, containsAll(['pubspec.yaml', 'l10n.yaml']));
        // BUILD.bazel and the root-import list are `mcgen buildgen`'s and
        // `mcgen wire`'s since T-0074 (buildgen_test and wire_test check
        // them on these packages).
        expect(gen.files.keys, isNot(contains('BUILD.bazel')));
        expect(gen.files.keys, isNot(contains('lib/src/di/flow_scope.dart')));
        expect(
          gen.files.length - ownedFiles.length,
          equals(compared),
          reason: 'most of the package is rendered and compared',
        );
      });

      test('T-0072-AC1 $name: gen writes only the manifest, and the '
          'committed manifest is the one it writes', () {
        final root = _copyRoot('manifest-$name', rel);
        addTearDown(() => root.deleteSync(recursive: true));
        final dir = p.join(root.path, rel);
        final before = hashTree(dir);
        final committed = File(
          p.join(dir, '.mcgen/manifest.json'),
        ).readAsStringSync();
        File(p.join(dir, '.mcgen/manifest.json')).deleteSync();
        final r = mcgen(['gen', '--root', root.path, name]);
        expect(r.code, 0, reason: '$r');
        expect(r.out, contains('write $rel/.mcgen/manifest.json'));
        expect(hashTree(dir), before, reason: 'only the manifest, unchanged');
        final manifest = Manifest.decode(committed);
        expect(manifest.ownership, 'ejected');
        final blocs = [
          for (final e in manifest.files.entries)
            if (e.key.endsWith('_details_bloc.dart')) e.value,
        ];
        expect(blocs, hasLength(1));
        expect(blocs.single.keep.keys, isNotEmpty);
      });
    });
  }

  group('T-0072-AC1 a spec change fails --check and names the file', () {
    test('T-0072-AC1 a changed API path makes --check exit 1 and name the '
        'API file (comics_details)', () {
      final root = _copyRoot(
        'path',
        _comics,
        edit: (s) =>
            s.replaceFirst('item_path: v1/comics/{id}', 'item_path: v1/c/{id}'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'comics_details',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains(
          '$_comics/lib/src/domain/api/comics_details_api.dart: round-trip: line ',
        ),
      );
      expect(RegExp('round-trip').allMatches(r.err), hasLength(1));
    });

    test('T-0072-AC1 a changed ARB string makes --check exit 1 and name the '
        'file (characters_details)', () {
      final root = _copyRoot(
        'arb',
        _characters,
        edit: (s) => s.replaceFirst('Add to favourites', 'Favourite it'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_details',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('$_characters/lib/src/l10n/characters_details_en.arb'),
      );
    });

    test('T-0072-AC1 a changed AC tag reaches the architecture test and '
        'names it', () {
      final root = _copyRoot(
        'prefix',
        _characters,
        edit: (s) => s.replaceFirst(
          'architecture: T-0067-AC6',
          'architecture: T-0067-AC9',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_details',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('$_characters/test/architecture/architecture_test.dart'),
      );
    });

    test('T-0072-AC1 an edit inside a keep region keeps --check green; an '
        'edit outside one fails it', () {
      final root = _copyRoot('keep', _comics);
      addTearDown(() => root.deleteSync(recursive: true));
      final bloc = File(
        p.join(
          root.path,
          _comics,
          'lib/src/presentation/bloc/comic_details_bloc.dart',
        ),
      );
      final original = bloc.readAsStringSync();
      bloc.writeAsStringSync(
        original.replaceFirst(
          '          _navigator.openCreator(id);\n',
          '          // A hand-written handler: track the tap first.\n'
              '          _navigator.openCreator(id);\n',
        ),
      );
      final inside = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'comics_details',
      ]);
      expect(inside.code, 0, reason: '$inside');

      bloc.writeAsStringSync(
        original.replaceFirst(
          'final ComicsDetailsNavigator _navigator;',
          'final ComicsDetailsNavigator _navigator; // edited',
        ),
      );
      final outside = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'comics_details',
      ]);
      expect(outside.code, 1, reason: '$outside');
      expect(
        outside.err,
        contains(
          '$_comics/lib/src/presentation/bloc/comic_details_bloc.dart: round-trip',
        ),
      );
    });
  });

  group('T-0072-AC2 the exemplars only gained keep markers, a spec and a '
      'manifest', () {
    test('T-0072-AC2 each hand-over handler of both exemplars is a keep '
        'region', () {
      for (final (rel, bloc, ids) in [
        (
          _comics,
          'lib/src/presentation/bloc/comic_details_bloc.dart',
          ['details.openCharacter', 'details.openCreator'],
        ),
        (
          _characters,
          'lib/src/presentation/bloc/character_details_bloc.dart',
          ['details.openComic'],
        ),
      ]) {
        final text = File(p.join(repoRoot, rel, bloc)).readAsStringSync();
        for (final id in ids) {
          expect(text, contains('// mcgen:keep $id\n'));
          expect(text, contains('// mcgen:end $id\n'));
        }
        final spec = File(p.join(repoRoot, rel, 'mcgen.yaml'))
            .readAsStringSync();
        expect(spec, contains('keep: [${ids.join(', ')}]'));
      }
    });
  });

  group('T-0072-AC3 a third section-detail module', () {
    test('T-0072-AC3 the probe spec lints clean and renders the same bytes '
        'in two roots', () {
      final a = _probeRoot('probe-a');
      final b = _probeRoot('probe-b');
      addTearDown(() {
        a.deleteSync(recursive: true);
        b.deleteSync(recursive: true);
      });
      final lint = mcgen(['spec', 'lint', '--root', a.path, 'zz_sc_probe']);
      expect(lint.code, 0, reason: '$lint');
      final ga = _render(a.path, _probeSpec);
      final gb = _render(b.path, _probeSpec);
      expect(
        {for (final f in ga.files.values) f.path: f.content},
        {for (final f in gb.files.values) f.path: f.content},
      );
      expect(ga.manifest.encode(), gb.manifest.encode());
    });

    test('T-0072-AC3 the probe is its own module, not an exemplar with '
        'names swapped', () {
      final root = _probeRoot('probe-names');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, _probeSpec);
      final paths = gen.files.keys.toSet();
      expect(
        paths,
        containsAll([
          'lib/src/domain/model/issue.dart',
          'lib/src/domain/model/series_id.dart',
          'lib/src/presentation/bloc/issue_details_bloc.dart',
          'lib/src/presentation/bloc/issue_favourite_bloc.dart',
          'test/feature/step/i_open_issue.dart',
          'test/feature/step/the_app_was_asked_to_open_series.dart',
        ]),
      );
      // No second request, no inner page, no analytics.
      expect(paths.where((f) => f.contains('analytics')), isEmpty);
      expect(paths.where((f) => f.contains('cover')), isEmpty);
      final flow = gen.files['lib/src/flow/zz_sc_probe_flow.dart']!.content;
      expect(flow, isNot(contains('AnalyticsFlowObserver')));
      expect(flow, contains("name: 'details'"));
      final bloc = gen
          .files['lib/src/presentation/bloc/issue_details_bloc.dart']!
          .content;
      expect(bloc, isNot(contains('.wait')));
      expect(bloc, contains('_startOpenGuard(id)'));
      expect(bloc, contains('// mcgen:keep details.openSeries'));
      // Nothing of the exemplars' vocabulary leaks into the probe.
      for (final f in gen.files.values) {
        expect(
          f.content.toLowerCase(),
          isNot(contains('character')),
          reason: '${f.path} mentions an exemplar',
        );
        expect(f.content, isNot(contains('T-0041')), reason: f.path);
        expect(f.content, isNot(contains('T-0067')), reason: f.path);
      }
      // A managed module gets the header; the pseudo-locale is computed.
      expect(bloc, startsWith('// Scaffolded by mcgen'));
      expect(
        gen.files['lib/src/l10n/zz_sc_probe_en_XA.arb']!.content,
        contains('"zzScProbeTitle": "[Íššúé ~~]"'),
      );
      expect(
        gen.files['test/feature/zz_sc_probe.feature']!.content,
        contains('  @MC-zz_sc_probe-01\n  Scenario: The page loads the issue'),
      );
      // The favourites probe asks the backend's comics kind, not "issue".
      expect(
        gen.files['test/feature/util/favourites_probe.dart']!.content,
        contains("'/v1/me/favourites/comic/\$issue'"),
      );
    });

    test('T-0072-AC3 a step no template knows is written once, as a failing '
        'stub', () {
      final root = _probeRoot(
        'probe-stub',
        edit: (s) => s.replaceFirst(
          "          - \"And I see {'Add to favourites'}\"\n",
          "          - \"And I see {'Add to favourites'}\"\n"
              "          - And the shelf holds {3} boxes of {'tea'}\n",
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, _probeSpec);
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
    });

    test("T-0072-AC3 section_detail's lint names what a spec gets wrong", () {
      List<String> lintWith(String Function(String) edit) {
        final root = _probeRoot('probe-lint', edit: edit);
        addTearDown(() => root.deleteSync(recursive: true));
        final r = mcgen(['spec', 'lint', '--root', root.path, 'zz_sc_probe']);
        expect(r.code, 1, reason: '$r');
        return [
          for (final l in r.err.trim().split('\n'))
            l.substring(l.indexOf('error')),
        ];
      }

      expect(
        lintWith((s) => s.replaceFirst('calls: openSeries', 'calls: openIt')),
        [
          'error [section_detail] options.opens[0].calls: the navigator has no method "openIt"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst('options:\n', 'options:\n  colour: red\n'),
        ),
        ['error [section_detail] options.colour: unknown key "colour"'],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst(
            '    - key: zzScProbeNotFoundTitle\n'
                '      description: Title when no issue has the requested id.\n'
                '      text: {en: Issue not found, de: Ausgabe nicht gefunden}\n',
            '',
          ),
        ),
        [
          'error [section_detail] l10n.strings: section_detail needs the string "zzScProbeNotFoundTitle"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst(
            'outbound: [openSeries(SeriesId), "requestSignIn() -> bool"]',
            'outbound: [openSeries(SeriesId)]',
          ),
        ),
        [
          'error [section_detail] navigator.outbound: the navigator needs requestSignIn() -> bool: the favourite signs in',
        ],
      );
    });

    test('T-0072-AC3 a prose slot no template uses fails gen, naming it', () {
      final root = _probeRoot(
        'probe-prose',
        edit: (s) => '$s  prose:\n    flow.dco: A typo.\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['gen', '--check', '--root', root.path, 'zz_sc_probe']);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('options.prose has slot(s) no template uses: flow.dco'),
      );
    });

    test('T-0072-AC3 a section_detail spec for a missing entity is a lint '
        'diagnostic, not a crash', () {
      final root = _probeRoot(
        'probe-entity',
        edit: (s) => s.replaceFirst('entity: Issue\n', 'entity: Gadget\n'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['gen', '--check', '--root', root.path, 'zz_sc_probe']);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('options.entity: no entity "Gadget" in entities'),
      );
    });
  });

  group('T-0072-AC4 the shared pieces', () {
    test('T-0072-AC4 comment lines and data-table rows among a scenario\'s '
        'steps are written to the feature and are no step', () {
      final spec = loadSpec(
        text: File(
          p.join(repoRoot, _characters, 'mcgen.yaml'),
        ).readAsStringSync(),
        file: '$_characters/mcgen.yaml',
        schema: SpecSchema.load(p.join(mcgenDir, 'schema', 'mcgen-1.json')),
      );
      final all = [
        for (final f in spec.bdd) ...[
          ...f.backgroundSteps,
          for (final s in f.scenarios) ...s.steps,
        ],
      ];
      expect(
        all.where((l) => l.trimLeft().startsWith(RegExp('[#|]'))),
        isNotEmpty,
        reason: 'the exemplar has comments and data tables among its steps',
      );
      final steps = allSteps(spec.bdd).toList();
      expect(
        steps.where((l) => l.trimLeft().startsWith(RegExp('[#|]'))),
        isEmpty,
      );
      final names = {for (final l in steps) stepFileName(l)};
      expect(names, isNot(contains('key_json')));
      expect(names, contains('the_analytics_event_was_tracked_with'));
    });

    test('T-0072-AC4 an outline placeholder is a step parameter like a '
        '{braced} one', () {
      expect(
        stepFileName('And the text scale is <scale>'),
        'the_text_scale_is',
      );
      expect(
        stepFileName("Then the app was asked to open comic {'A'}"),
        'the_app_was_asked_to_open_comic',
      );
    });

    test('T-0072-AC4 reflow fills a doc comment greedily and keeps lists', () {
      expect(
        reflow('one two three four five six', indent: 0, width: 17),
        'one two three\nfour five six',
      );
      expect(
        reflow('First para.\n\nSecond para.', indent: 2),
        'First para.\n\nSecond para.',
      );
      expect(reflow('- a\n- b'), '- a\n- b');
    });
  });
}
