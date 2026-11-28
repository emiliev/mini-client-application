// T-0073: the search archetype (P2-05). Its two exemplars, the grouped
// feature/discovery/discovery_search and the paged
// feature/characters/characters_search, are its golden: each render must
// equal its exemplar outside keep regions and owned files (plan 02 KD1,
// ADR-0017). A third, throwaway paged spec proves the templates are not the
// exemplars with names swapped (tool/T-0073-AC3_sr_probe.sh runs it under
// Bazel too).

import 'dart:io';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/support.dart';

const _grouped = 'feature/discovery/discovery_search';
const _paged = 'feature/characters/characters_search';
const _both = [_grouped, _paged];

String _name(String rel) => p.basename(rel);

/// A temp root holding a copy of the exemplar [rel] and every utility
/// pubspec (so the package catalog knows the first-party deps), with [edit]
/// applied to the spec.
Directory _copyRoot(String rel, String tag, {String Function(String)? edit}) {
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
  final source = p.join(repoRoot, rel);
  for (final f in listTree(source)) {
    final out = File(p.join(root.path, rel, f));
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(File(p.join(source, f)).readAsBytesSync());
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
    schema: schema,
  ),
  index: RepoIndex.scan(root),
  forbidden: [root, mcgenDir],
);

const _probeRel = 'feature/zz_probe/zz_sr_probe';

/// The probe spec in a temp root at feature/zz_probe/zz_sr_probe.
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
  final spec = readFixture('zz_sr_probe/mcgen.yaml');
  writeFile(root, '$_probeRel/mcgen.yaml', edit == null ? spec : edit(spec));
  return root;
}

void main() {
  group('T-0073-AC1 the exemplars round-trip', () {
    for (final rel in _both) {
      final name = _name(rel);
      test(
        'T-0073-AC1 mcgen gen $name --check exits 0 against the exemplar',
        () {
          final r = mcgen(['gen', '--check', name], cwd: repoRoot);
          expect(r.code, 0, reason: '$r');
          expect(r.out, contains('$rel: up to date'));
          final c = mcgen(['check', name], cwd: repoRoot);
          expect(c.code, 0, reason: '$c');
        },
      );

      test('T-0073-AC1 the round-trip golden of $name: compareToExemplar '
          'finds the render identical to the real exemplar', () {
        final gen = _render(repoRoot, '$rel/mcgen.yaml');
        final diff = compareToExemplar(gen, p.join(repoRoot, rel));
        expect(diff.identical, isTrue, reason: '$diff');
        final owned = {
          for (final f in gen.files.values)
            if (f.ownership == 'owned') f.path,
        };
        // Every step mcgen has no template for is an owned stub; what the
        // module hand-writes is never emitted for an exemplar.
        for (final path in owned) {
          expect(
            path,
            startsWith('test/feature/step/'),
            reason: 'only step stubs are emitted as owned: $path',
          );
        }
        for (final f in [
          'lib/src/presentation/bloc/${name}_bloc.dart',
          'lib/src/presentation/page/${name}_page.dart',
          'lib/src/presentation/widget/search_history_view.dart',
          'lib/src/di/di_module.dart',
          'lib/src/l10n/${name}_de.arb',
          'pubspec.yaml',
          'test/architecture/architecture_test.dart',
        ]) {
          expect(gen.files.keys, contains(f));
          expect(gen.files[f]!.ownership, 'managed');
        }
      });
    }

    test('T-0073-AC1 a changed spec field makes --check exit 1 and name the '
        'file', () {
      final paged = _copyRoot(
        _paged,
        'field-paged',
        edit: (s) => s.replaceFirst(
          'de: Figuren nach Namen suchen',
          'de: Helden suchen',
        ),
      );
      final grouped = _copyRoot(
        _grouped,
        'field-grouped',
        edit: (s) => s.replaceFirst('min_length: 2', 'min_length: 3'),
      );
      addTearDown(() {
        paged.deleteSync(recursive: true);
        grouped.deleteSync(recursive: true);
      });
      final a = mcgen([
        'gen',
        '--check',
        '--root',
        paged.path,
        'characters_search',
      ]);
      expect(a.code, 1, reason: '$a');
      expect(
        a.err,
        contains(
          '$_paged/lib/src/l10n/characters_search_de.arb: round-trip: line 4:',
        ),
      );
      expect(
        RegExp('round-trip').allMatches(a.err),
        hasLength(1),
        reason: a.err,
      );

      final b = mcgen([
        'gen',
        '--check',
        '--root',
        grouped.path,
        'discovery_search',
      ]);
      expect(b.code, 1, reason: '$b');
      expect(
        b.err,
        contains(
          '$_grouped/lib/src/presentation/bloc/discovery_search_bloc.dart: '
          'round-trip: line 26: const int minQueryLength = 3; | const int minQueryLength = 2;',
        ),
      );
    });

    test('T-0073-AC1 a facet renamed in the spec changes the bloc, the event '
        'and the page, and --check names each', () {
      final root = _copyRoot(
        _paged,
        'facet',
        edit: (s) =>
            s.replaceFirst('event: teamChanged', 'event: squadChanged'),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen([
        'gen',
        '--check',
        '--root',
        root.path,
        'characters_search',
      ]);
      expect(r.code, 1, reason: '$r');
      expect(r.err, contains('characters_search_bloc.dart: round-trip'));
      expect(r.err, contains('characters_search_event.dart: round-trip'));
    });

    test('T-0073-AC1 an edit inside the keep region keeps --check green; an '
        'edit outside one fails it', () {
      for (final (rel, call) in [
        (_paged, '        _navigator.openCharacter(id);\n'),
        (_grouped, '          case CharacterHit(:final id):\n'),
      ]) {
        final name = _name(rel);
        final root = _copyRoot(rel, 'keep-$name');
        addTearDown(() => root.deleteSync(recursive: true));
        final bloc = File(
          p.join(root.path, rel, 'lib/src/presentation/bloc/${name}_bloc.dart'),
        );
        final original = bloc.readAsStringSync();
        expect(original, contains(call));
        bloc.writeAsStringSync(
          original.replaceFirst(
            call,
            '        // A hand-written handler.\n$call',
          ),
        );
        final inside = mcgen(['gen', '--check', '--root', root.path, name]);
        expect(inside.code, 0, reason: '$inside');

        bloc.writeAsStringSync(
          original.replaceFirst('int _generation = 0;', 'int _generation = 1;'),
        );
        final outside = mcgen(['gen', '--check', '--root', root.path, name]);
        expect(outside.code, 1, reason: '$outside');
        expect(outside.err, contains('${name}_bloc.dart: round-trip'));
      }
    });

    test('T-0073-AC1 gen writes only the manifest into an exemplar, and the '
        'committed manifest is the one it writes', () {
      for (final rel in _both) {
        final name = _name(rel);
        final root = _copyRoot(rel, 'manifest-$name');
        addTearDown(() => root.deleteSync(recursive: true));
        final dir = p.join(root.path, rel);
        final before = hashTree(dir);
        final committed = File(p.join(dir, '.mcgen/manifest.json'))
            .readAsStringSync();
        File(p.join(dir, '.mcgen/manifest.json')).deleteSync();
        final r = mcgen(['gen', '--root', root.path, name]);
        expect(r.code, 0, reason: '$r');
        expect(r.out, contains('write $rel/.mcgen/manifest.json'));
        expect(hashTree(dir), before, reason: 'only the manifest, unchanged');
        final manifest = Manifest.decode(committed);
        expect(manifest.ownership, 'ejected');
        expect(
          manifest
              .files['lib/src/presentation/bloc/${name}_bloc.dart']!
              .keep
              .keys,
          ['search.open'],
        );
      }
    });
  });

  group('T-0073-AC2 the exemplars stay what they were', () {
    test('T-0073-AC2 the only keep region of each exemplar is the open '
        'handler, and the hand-written files are owned, not rendered', () {
      for (final rel in _both) {
        final gen = _render(repoRoot, '$rel/mcgen.yaml');
        final keeps = {
          for (final f in gen.files.values)
            for (final k in gen.manifest.files[f.path]!.keep.keys) k,
        };
        expect(keeps, {'search.open'});
        // The domain, the results widgets, the env and the contract test are
        // the module's own: the exemplar spec never renders them.
        for (final own in [
          'lib/src/domain/repository/${_name(rel)}_repository.dart',
          'test/feature/util/${_name(rel)}_env.dart',
          'test/flow_scope_test.dart',
          'BUILD.bazel',
        ]) {
          expect(gen.files.keys, isNot(contains(own)), reason: own);
        }
      }
    });
  });

  group('T-0073-AC3 a third search module', () {
    test('T-0073-AC3 the probe spec lints clean and renders the same bytes '
        'in two roots', () {
      final a = _probeRoot('probe-a');
      final b = _probeRoot('probe-b');
      addTearDown(() {
        a.deleteSync(recursive: true);
        b.deleteSync(recursive: true);
      });
      final lint = mcgen(['spec', 'lint', '--root', a.path, 'zz_sr_probe']);
      expect(lint.code, 0, reason: '$lint');
      const spec = '$_probeRel/mcgen.yaml';
      final ga = _render(a.path, spec);
      final gb = _render(b.path, spec);
      expect(
        {for (final f in ga.files.values) f.path: f.content},
        {for (final f in gb.files.values) f.path: f.content},
      );
      expect(ga.manifest.encode(), gb.manifest.encode());
    });

    test('T-0073-AC3 the probe is its own module, not an exemplar with names '
        'swapped', () {
      final root = _probeRoot('probe-names');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '$_probeRel/mcgen.yaml');
      expect(
        gen.files.keys,
        containsAll([
          'lib/src/domain/model/comic.dart',
          'lib/src/domain/model/comic_dto.dart',
          'lib/src/domain/model/comic_facets.dart',
          'lib/src/presentation/widget/comic_result_tile.dart',
          'test/feature/step/i_tap_the_sort_chip.dart',
          'test/feature/step/the_app_was_asked_to_open_comic.dart',
          'BUILD.bazel',
        ]),
      );
      // One facet, no team: no team step, no analytics screen, no min length.
      expect(gen.files.keys.where((f) => f.contains('team')), isEmpty);
      expect(
        gen.files.keys,
        isNot(contains('lib/src/domain/model/character_analytics.dart')),
      );
      final bloc =
          gen.files['lib/src/presentation/bloc/zz_sr_probe_bloc.dart']!.content;
      expect(bloc, isNot(contains('minQueryLength')));
      expect(bloc, contains('const int comicsSearchPageSize = 20;'));
      // Nothing of the exemplars' vocabulary leaks into the probe.
      for (final f in gen.files.values) {
        final text = f.content.toLowerCase();
        for (final word in [
          'character',
          'spindle',
          'team',
          'discovery',
          'amber alchemist',
        ]) {
          expect(
            text,
            isNot(contains(word)),
            reason: '${f.path} mentions $word',
          );
        }
        for (final task in ['T-0071', 'T-0046', 'P1-19']) {
          expect(f.content, isNot(contains(task)), reason: f.path);
        }
      }
      // A managed module gets the header; the pseudo-locale is computed and
      // keeps the placeholder.
      expect(bloc, startsWith('// Scaffolded by mcgen'));
      expect(
        gen.files['lib/src/l10n/zz_sr_probe_en_XA.arb']!.content,
        contains('{query}'),
      );
    });

    test('T-0073-AC3 the template covers every behaviour the task names', () {
      final root = _probeRoot('probe-behaviour');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '$_probeRel/mcgen.yaml');
      final bloc =
          gen.files['lib/src/presentation/bloc/zz_sr_probe_bloc.dart']!.content;
      final state = gen
          .files['lib/src/presentation/bloc/zz_sr_probe_state.dart']!
          .content;
      final event = gen
          .files['lib/src/presentation/bloc/zz_sr_probe_event.dart']!
          .content;
      final di = gen.files['lib/src/di/di_module.dart']!.content;
      // DebouncedQuery and SearchHistory, each with its own key.
      expect(bloc, contains('DebouncedQuery('));
      expect(bloc, contains('delay: searchDebounce'));
      expect(di, contains("searchHistoryStoreKey = 'zz_sr_probe.history'"));
      expect(di, contains('SearchHistory(store, cap: searchHistoryCap'));
      // The generation guard, one paging controller per search, the facet.
      expect(bloc, contains('final generation = ++_generation;'));
      expect(bloc, contains('if (generation == _generation)'));
      expect(bloc, contains('PagingController<Comic>('));
      expect(bloc, contains('_facets = _facets.withSort(sort);'));
      expect(
        event,
        contains('const factory ZzSrProbeEvent.sortChanged(ComicSort sort)'),
      );
      // Every state.
      for (final s in ['idle', 'searching', 'results', 'empty', 'failure']) {
        expect(state, contains('ZzSrProbeState.$s('), reason: s);
      }
      // The result list is keyed by the query and the facets.
      expect(
        gen.files['lib/src/presentation/page/zz_sr_probe_page.dart']!.content,
        contains('key: ValueKey((query, facets)),'),
      );
    });

    test('T-0073-AC3 a module with its own files gets none of the skeleton, '
        'and the skeleton files are owned', () {
      final root = _probeRoot('probe-owned');
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '$_probeRel/mcgen.yaml');
      for (final f in [
        'BUILD.bazel',
        'lib/src/domain/api/zz_sr_probe_api.dart',
        'lib/src/domain/repository/zz_sr_probe_repository.dart',
        'test/feature/util/zz_sr_probe_env.dart',
        'test/contract/zz_sr_probe_api_contract_test.dart',
        'test/flow_scope_test.dart',
      ]) {
        expect(gen.files[f]?.ownership, 'owned', reason: f);
      }
      expect(
        gen.files['test/architecture/architecture_test.dart']!.ownership,
        'managed',
      );
    });

    test('T-0073-AC3 a step no template knows is written once, as a failing '
        'stub', () {
      final root = _probeRoot(
        'probe-stub',
        edit: (s) => s.replaceFirst(
          "          - \"And the sort {'Title A–Z'} is chosen\"\n",
          "          - \"And the sort {'Title A–Z'} is chosen\"\n"
              "          - And the shelf holds {3} boxes of {'tea'}\n",
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final gen = _render(root.path, '$_probeRel/mcgen.yaml');
      final stub =
          gen.files['test/feature/step/the_shelf_holds_boxes_of.dart']!;
      expect(stub.ownership, 'owned');
      expect(
        stub.content,
        contains("fail('step \"theShelfHoldsBoxesOf\" is not written yet');"),
      );
    });

    test("T-0073-AC3 search's lint names what a spec gets wrong", () {
      List<String> lintWith(String Function(String) edit) {
        final root = _probeRoot('probe-lint', edit: edit);
        addTearDown(() => root.deleteSync(recursive: true));
        final r = mcgen(['spec', 'lint', '--root', root.path, 'zz_sr_probe']);
        expect(r.code, 1, reason: '$r');
        return [
          for (final l in r.err.trim().split('\n'))
            l.substring(l.indexOf('error')),
        ];
      }

      expect(
        lintWith(
          (s) => s.replaceFirst('options:\n', 'options:\n  colour: red\n'),
        ),
        ['error [search] options.colour: unknown key "colour"'],
      );
      expect(
        lintWith((s) => s.replaceFirst('open: openComic', 'open: openSeries')),
        [
          'error [search] options.results.open: the navigator has no method "openSeries"',
        ],
      );
      expect(
        lintWith((s) => s.replaceFirst('mode: paged', 'mode: wide')),
        [
          'error [search] options.mode: "mode" must be paged or grouped, not "wide"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst(
            '    - {key: zzSrProbeNoRecent,',
            '    - {key: zzSrProbeNoRecentX,',
          ),
        ),
        [
          'error [search] l10n.strings: search needs the string "zzSrProbeNoRecent"',
        ],
      );
      expect(
        lintWith(
          (s) => s.replaceFirst(
            '    - {name: sort, type: ComicSort, event: sortChanged, doc: A sort chip was chosen.}\n',
            '',
          ),
        ),
        [
          'error [search] options.facets: a paged search needs at least one facet',
        ],
      );
    });

    test('T-0073-AC3 a prose slot no template uses fails gen, naming it', () {
      final root = _probeRoot(
        'probe-prose',
        edit: (s) => '$s  prose:\n    flow.dco: A typo.\n',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['gen', '--check', '--root', root.path, 'zz_sr_probe']);
      expect(r.code, 1, reason: '$r');
      expect(
        r.err,
        contains('options.prose has slot(s) no template uses: flow.dco'),
      );
    });

    test('T-0073-AC3 a missing de string is a lint error, not pseudo text', () {
      final root = _probeRoot(
        'probe-de',
        edit: (s) => s.replaceFirst(
          'text: {en: Search comics, de: Comics suchen}',
          'text: {en: Search comics}',
        ),
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final r = mcgen(['spec', 'lint', '--root', root.path, 'zz_sr_probe']);
      expect(r.code, 1, reason: '$r');
      expect(r.err, contains('"zzSrProbeTitle" has no "de" text'));
    });
  });

  group('T-0073-AC4 the shared pieces', () {
    test('T-0073-AC4 the list-detail exemplar still round-trips: the shared '
        'code is untouched', () {
      final r = mcgen(['gen', '--check', 'characters_list'], cwd: repoRoot);
      expect(r.code, 0, reason: '$r');
      expect(r.out, contains('characters_list: up to date'));
    });
  });
}
