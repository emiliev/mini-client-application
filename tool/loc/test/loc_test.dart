import 'dart:convert';
import 'dart:io';

import 'package:loc/count.dart';
import 'package:loc/loc.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final fixtures = p.join(Directory.current.path, 'test', 'fixtures');

/// Copies [src] into [dst], dropping the `.fixture` suffix so that fixture
/// sources are not analysed or counted as real code in this repository.
void materialise(String src, String dst) {
  for (final e in Directory(src).listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = p.relative(e.path, from: src);
    final out = File(p.join(dst, rel.replaceAll(RegExp(r'\.fixture$'), '')));
    out.parent.createSync(recursive: true);
    e.copySync(out.path);
  }
}

int countOf(String name) => scanDart(
        File(p.join(fixtures, 'counting', '$name.dart.fixture'))
            .readAsStringSync())
    .lines
    .length;

late Directory tmp;
late String corpus;
late String genroot;

Map<String, Object?> run({bool strict = false, bool gen = false}) => runLoc(
        LocOptions(
          root: corpus,
          strict: strict,
          generatedRoot: gen ? genroot : null,
          commit: 'test',
        )).json;

Map<String, Object?> m(Object? o) => (o as Map).cast<String, Object?>();

void main() {
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loc_test_');
    corpus = p.join(tmp.path, 'corpus');
    genroot = p.join(tmp.path, 'genroot');
    materialise(p.join(fixtures, 'corpus'), corpus);
    materialise(p.join(fixtures, 'genroot'), genroot);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('T-0015-AC1 per-file counts', () {
    test('T-0015-AC1 line comments, trailing comments, code after comment', () {
      expect(countOf('c1_line_comments'), 4); // lines 3,6,7,8
    });
    test('T-0015-AC1 nested block comments and code after close', () {
      expect(countOf('c2_nested_block'), 4); // lines 2,5,7,8
    });
    test('T-0015-AC1 multi-line strings, // in strings, raw strings', () {
      // 1; 2,3,5,6 (blank line 4 skipped); 7,8,9; 10; 12; 13
      expect(countOf('c3_strings'), 11);
    });
    test('T-0015-AC1 doc comments and blank lines', () {
      expect(countOf('c4_doc_blank'), 4); // lines 3,7,10,11
    });
    test('T-0015-AC1 imports and mixins are tallied', () {
      final s = scanDart(File(
              p.join(fixtures, 'counting', 'c5_imports_mixins.dart.fixture'))
          .readAsStringSync());
      expect(s.lines.length, 5);
      expect(s.imports, 2);
      expect(s.mixins, 2);
    });
  });

  group('T-0015-AC2 generated exclusion', () {
    test('T-0015-AC2 generated suffixes, l10n and BDD are excluded', () {
      final j = run();
      final t = m(j['totals']);
      expect(m(t['generated']).values.every((v) => v == 0), isTrue);
      expect(j['excluded_committed_generated'], [
        'feature/a/lib/l10n/app_localizations.dart',
        'feature/a/lib/l10n/app_localizations_en.dart',
        'feature/a/lib/src/di/injection.config.dart',
        'feature/a/lib/src/model/item.freezed.dart',
        'feature/a/lib/src/model/item.g.dart',
        'feature/a/lib/src/model/rest.g.dart',
        'feature/a/lib/src/router.gr.dart',
        'feature/a/test/login_test.dart',
      ]);
      // none of them leaked into source or test
      expect(m(t['source']), {'hand': 11, 'scaffold': 8});
      expect(m(t['test']), {'hand': 3, 'scaffold': 0});
    });

    test('T-0015-AC2 generated bucket only with --generated-root', () {
      final g = m(m(run(gen: true)['totals'])['generated']);
      expect(g['freezed'], 2);
      expect(g['json'], 3);
      expect(g['l10n'], 1);
      expect(g['retrofit'], 0);
      expect(m(m(run()['totals'])['generated'])['freezed'], 0);
    });
  });

  group('T-0015-AC3 classification', () {
    test('T-0015-AC3 tiers, test, testonly and tooling buckets', () {
      final t = m(run()['totals']);
      expect(t['tooling'], 1);
      expect(t['packages'], 4);
      expect(m(t['files']), {'lib': 7, 'test': 2, 'other': 9});
      final mods = {
        for (final x in (run()['modules'] as List)) m(x)['name']: m(x),
      };
      expect(m(mods['mc_test_utils']!['test']), {'hand': 1, 'scaffold': 0});
      expect(m(mods['mc_test_utils']!['source']), {'hand': 0, 'scaffold': 0});
      expect(mods['shell']!['tier'], 'app');
      expect(mods['feature_a']!['tier'], 'feature');
      expect(mods['utility_core']!['tier'], 'utility');
    });

    test('T-0015-AC3 manifest hashes and keep regions split hand/scaffold', () {
      final mods = {
        for (final x in (run()['modules'] as List)) m(x)['name']: m(x),
      };
      final a = mods['feature_a']!;
      // item 4 scaffold; a_bloc 4 scaffold + 2 keep (hand); drift drifted 3;
      // di 1 unlisted; a.dart 1 unlisted
      expect(m(a['source']), {'hand': 7, 'scaffold': 8});
      expect(m(a['test']), {'hand': 2, 'scaffold': 0});
      expect(a['archetype'], 'list_detail');
      expect(m(a['layers']), {
        'domain/model': 4,
        'presentation/bloc': 6,
        'domain/usecase': 3,
        'di': 1,
        'other': 1,
      });
    });

    test('T-0015-AC3 without a manifest everything is hand', () {
      File(p.join(corpus, 'feature/a/.mcgen/manifest.json')).deleteSync();
      final t = m(run()['totals']);
      expect(m(t['source']), {'hand': 19, 'scaffold': 0});
    });
  });

  group('T-0015-AC4 schema and determinism', () {
    test('T-0015-AC4 valid mc-loc/1 JSON with all sections', () {
      final j = jsonDecode(encodeJson(run())) as Map<String, dynamic>;
      expect(j['schema'], 'mc-loc/1');
      expect(j['rule'], 'D8');
      for (final k in [
        'totals',
        'by_archetype',
        'by_tier',
        'modules',
        'histograms',
        'mixins',
        'gates',
        'non_dart',
      ]) {
        expect(j.containsKey(k), isTrue, reason: k);
      }
      final gen = (j['totals']['generated'] as Map).keys;
      expect(gen, containsAll(
          ['freezed', 'json', 'retrofit', 'injectable', 'l10n', 'bdd', 'go_router']));
      expect(j['histograms'].keys,
          ['file_loc', 'imports_per_file', 'pkg_fan_in', 'pkg_fan_out']);
      expect(j['by_archetype']['list_detail']['source'], 15);
      expect(j['by_tier']['feature']['modules'], 1);
      expect(j['non_dart'], {
        'arb_keys': 2,
        'asset_files': 1,
        'feature_scenarios': 2,
        'fixture_files': 1,
      });
      expect(j['mixins'], {'authored': 0, 'generated': 0});
    });

    test('T-0015-AC4 fan-in/out histograms from sibling dependencies', () {
      final h = m(run()['histograms']);
      int at(String k, String bucket) => ((h[k] as List)
              .firstWhere((e) => (e as Map)['bucket'] == bucket) as Map)['count']
          as int;
      expect(at('pkg_fan_out', '0'), 2); // utility_core, mc_test_utils
      expect(at('pkg_fan_out', '1'), 2); // shell, feature_a
      expect(at('pkg_fan_in', '1'), 2); // feature_a, utility_core
    });

    test('T-0015-AC4 two runs are byte-identical, Markdown included', () {
      final a = runLoc(LocOptions(root: corpus, generatedRoot: genroot, commit: 'x'));
      final b = runLoc(LocOptions(root: corpus, generatedRoot: genroot, commit: 'x'));
      expect(encodeJson(a.json), encodeJson(b.json));
      expect(a.markdown, b.markdown);
      expect(a.markdown, contains('# LOC report'));
      expect(a.markdown, contains('Top 20 modules'));
    });
  });

  group('T-0015-AC5 strict mode', () {
    test('T-0015-AC5 committed generated files fail naming each file', () {
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      expect(r.failures, hasLength(8));
      expect(r.failures,
          contains('committed generated file (D7): feature/a/lib/src/model/item.g.dart'));
      expect(m(r.json['gates'])['pass'], isFalse);
    });

    test('T-0015-AC5 non-strict never fails', () {
      expect(runLoc(LocOptions(root: corpus, commit: 't')).failures, isEmpty);
    });

    test('T-0015-AC5 files in fallback.yaml pass and count as generated', () {
      final listed = [
        'feature/a/lib/l10n/app_localizations.dart',
        'feature/a/lib/l10n/app_localizations_en.dart',
        'feature/a/lib/src/di/injection.config.dart',
        'feature/a/lib/src/model/item.freezed.dart',
        'feature/a/lib/src/model/item.g.dart',
        'feature/a/lib/src/model/rest.g.dart',
        'feature/a/lib/src/router.gr.dart',
        'feature/a/test/login_test.dart',
      ];
      File(p.join(corpus, 'tool/build_runner_overlay/fallback.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
            'generators: [freezed]\noutputs:\n${listed.map((f) => '  - $f\n').join()}');
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      expect(r.failures, isEmpty);
      final t = m(r.json['totals']);
      expect(m(t['generated']), {
        'freezed': 2,
        'json': 2,
        'retrofit': 2,
        'injectable': 1,
        'l10n': 3,
        'bdd': 1,
        'go_router': 3,
        'other': 0,
      });
      expect(m(t['source']), {'hand': 11, 'scaffold': 8});
    });

    test('T-0015-AC5 a fallback listing only some files still fails the rest', () {
      File(p.join(corpus, 'tool/build_runner_overlay/fallback.yaml'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('- feature/a/lib/src/model/item.g.dart\n');
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      expect(r.failures, hasLength(7));
      expect(r.failures.any((f) => f.contains('item.g.dart')), isFalse);
    });
  });
}
