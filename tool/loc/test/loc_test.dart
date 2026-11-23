import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:loc/count.dart';
import 'package:loc/loc.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolved from the package location so the cwd does not matter.
late final String fixtures;

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

void write(String rel, String content) => File(p.join(corpus, rel))
  ..parent.createSync(recursive: true)
  ..writeAsStringSync(content);

void git(List<String> args) {
  final r = Process.runSync('git', args, workingDirectory: corpus);
  if (r.exitCode != 0) fail('git $args failed: ${r.stderr}');
}

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
  setUpAll(() async {
    final lib = await Isolate.resolvePackageUri(Uri.parse('package:loc/loc.dart'));
    fixtures = p.join(p.dirname(p.dirname(lib!.toFilePath())), 'test', 'fixtures');
  });

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
      expect(s.lines.length, 6);
      expect(s.imports, 2);
      expect(s.mixins, 1); // MixinDeclaration only; `mixin class` is a class
      expect(s.withApplications, 2);
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
      expect(g['l10n'], 1);
      expect(m(m(run()['totals'])['generated'])['freezed'], 0);
    });

    test('T-0015-AC2 generated root ignores external/ and non-generated copies', () {
      final g = m(m(run(gen: true)['totals'])['generated']);
      // genroot also holds external/x/y.freezed.dart (1 line) and a plain
      // source copy (1 line): neither may be counted.
      expect(g.values.fold<int>(0, (a, v) => a + (v as int)), 2 + 2 + 3 + 1);
    });

    test('T-0015-AC2 combined .g.dart is split by generator section', () {
      final g = m(m(run(gen: true)['totals'])['generated']);
      expect(g['json'], 2); // preamble + _$BFromJson
      expect(g['retrofit'], 3); // class _Api { int x = 1; }
    });

    test('T-0015-AC2 l10n rule needs l10n.yaml and the configured output dir', () {
      File(p.join(corpus, 'feature/a/l10n.yaml')).deleteSync();
      var j = run();
      expect(j['excluded_committed_generated'], isNot(contains('feature/a/lib/l10n/app_localizations.dart')));
      expect(m(m(j['totals'])['source'])['hand'], 11 + 3);
      // with the yaml but a file outside the output dir
      File(p.join(corpus, 'feature/a/l10n.yaml')).writeAsStringSync('arb-dir: lib/l10n\n');
      write('feature/a/lib/other/app_localizations.dart', 'int z = 1;\n');
      j = run();
      expect(j['excluded_committed_generated'], isNot(contains('feature/a/lib/other/app_localizations.dart')));
      expect(m(m(j['totals'])['source'])['hand'], 11 + 1);
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

    test('T-0015-AC3 files outside any module are counted, warned and fail strict', () {
      write('utility/stray/lib/s.dart', 'int s = 1;\nint t = 2;\n');
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      final t = m(r.json['totals']);
      expect(m(t['source']), {'hand': 13, 'scaffold': 8});
      expect(t['packages'], 4);
      final syn = (r.json['modules'] as List).map(m).firstWhere((x) => x['synthetic'] == true);
      expect(syn['name'], '(unowned:utility)');
      expect(m(syn['source'])['hand'], 2);
      expect(r.warnings.any((w) => w.contains('utility/stray/lib/s.dart')), isTrue);
      expect(r.failures.any((w) => w.contains('outside any module')), isTrue);
    });

    test('T-0015-AC3 unparseable pubspec.yaml is not silently dropped', () {
      write('app/shell/pubspec.yaml', ': : [\n');
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      expect(m(m(r.json['totals'])['source'])['hand'], 11 + 0); // main.dart still counted
      expect(r.warnings.any((w) => w.contains('unparseable pubspec.yaml')), isTrue);
      expect(r.failures.any((w) => w.contains('unparseable pubspec.yaml')), isTrue);
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
      expect(j['mixins'], {'authored': 0, 'generated': 0, 'with_applications': 0});
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
    test('T-0015-AC5 malformed .arb and manifest warn instead of crashing', () {
      write('feature/a/lib/l10n/app_en.arb', '{ nope');
      write('feature/a/.mcgen/manifest.json', '[1,');
      final r = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      final t = m(r.json['totals']);
      expect(m(r.json['non_dart'])['arb_keys'], 0);
      expect(m(t['source']), {'hand': 19, 'scaffold': 0});
      expect(r.failures.any((w) => w.contains('malformed .arb')), isTrue);
      expect(r.failures.any((w) => w.contains('malformed feature/a/.mcgen/manifest.json')), isTrue);
    });

    test('T-0015-AC5 strict uses git ls-files: untracked files only on request', () {
      git(['init', '-q']);
      git(['add', '-A']);
      write('feature/a/lib/untracked.g.dart', 'int u = 1;\n');
      final tracked = runLoc(LocOptions(root: corpus, strict: true, commit: 't'));
      expect(tracked.failures, hasLength(8));
      expect(tracked.warnings.any((w) => w.contains('not in a git work tree')), isFalse);
      expect(tracked.failures.any((w) => w.contains('untracked.g.dart')), isFalse);
      final all = runLoc(LocOptions(
          root: corpus, strict: true, includeUntracked: true, commit: 't'));
      expect(all.failures, hasLength(9));
    });

    test('T-0015-AC5 outside git it walks the tree and warns', () {
      final r = runLoc(LocOptions(root: corpus, commit: 't'));
      expect(r.warnings.single, contains('not in a git work tree'));
    });

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
