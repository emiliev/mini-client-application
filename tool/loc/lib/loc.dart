import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'count.dart';

const schemaId = 'mc-loc/1';
const tiers = ['app', 'feature', 'utility'];
const _testDirs = {'test', 'integration_test', 'test_driver'};
const generatorKinds = [
  'freezed',
  'json',
  'retrofit',
  'injectable',
  'l10n',
  'bdd',
  'go_router',
];

const layerNames = [
  'di',
  'domain/model',
  'domain/api',
  'domain/repository',
  'domain/usecase',
  'domain/rules',
  'presentation/bloc',
  'presentation/page',
  'presentation/widget',
  'flow',
  'navigator',
  'l10n',
  'other',
];

class LocOptions {
  LocOptions({
    required this.root,
    this.generatedRoot,
    this.strict = false,
    this.stamp,
    this.commit,
  });

  final String root;
  final String? generatedRoot;
  final bool strict;
  final String? stamp;
  final String? commit;
}

class LocResult {
  LocResult(this.json, this.markdown, this.failures);
  final Map<String, Object?> json;
  final String markdown;
  final List<String> failures;
}

class _Module {
  _Module(this.dir, this.name, this.testonly, this.deps, this.archetype,
      this.manifest, this.l10nStem);
  final String dir; // relative, posix
  final String name;
  final bool testonly;
  final List<String> deps;
  final String archetype;
  final Map<String, Map<String, Object?>> manifest;
  final String l10nStem;
  String get tier => dir.split('/').first;

  final source = _HandScaffold();
  final test = _HandScaffold();
  final layers = <String, int>{};
  int libFiles = 0;
  int testFiles = 0;
}

class _HandScaffold {
  int hand = 0;
  int scaffold = 0;
  int get total => hand + scaffold;
}

bool _ignoredSegment(String s) =>
    s.startsWith('.') ||
    s == 'build' ||
    s == 'node_modules' ||
    s.startsWith('bazel-');

List<String> _walk(String root) {
  final out = <String>[];
  void rec(Directory d, String rel) {
    final entries = d.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final e in entries) {
      final name = p.basename(e.path);
      if (_ignoredSegment(name)) continue;
      final r = rel.isEmpty ? name : '$rel/$name';
      if (e is Directory) {
        rec(e, r);
      } else if (e is File) {
        out.add(r);
      }
    }
  }

  rec(Directory(root), '');
  return out;
}

String? _genSuffixKind(String path) {
  if (path.endsWith('.freezed.dart')) return 'freezed';
  if (path.endsWith('.gr.dart')) return 'go_router';
  if (path.endsWith('.config.dart')) return 'injectable';
  if (path.endsWith('.g.dart')) return 'json';
  return null;
}

Object? _loadYaml(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    return loadYaml(f.readAsStringSync());
  } on YamlException {
    return null;
  }
}

Set<String> _fallbackFiles(String root) {
  final y = _loadYaml(p.join(root, 'tool/build_runner_overlay/fallback.yaml'));
  final out = <String>{};
  void collect(Object? n) {
    if (n is String) {
      if (n.endsWith('.dart')) out.add(n);
    } else if (n is YamlList) {
      n.forEach(collect);
    } else if (n is YamlMap) {
      n.values.forEach(collect);
    }
  }

  collect(y);
  return out;
}

String _layerOf(String relInModule) {
  final s = '/${relInModule.toLowerCase()}';
  bool has(String x) => s.contains('/$x/') || s.contains('/$x.');
  if (s.contains('/l10n/')) return 'l10n';
  if (has('di')) return 'di';
  if (s.contains('/domain/model') || s.contains('/domain/models')) {
    return 'domain/model';
  }
  if (s.contains('/domain/api')) return 'domain/api';
  if (s.contains('/domain/repositor')) return 'domain/repository';
  if (s.contains('/domain/usecase')) return 'domain/usecase';
  if (s.contains('/domain/rules')) return 'domain/rules';
  if (s.contains('/presentation/bloc')) return 'presentation/bloc';
  if (s.contains('/presentation/page')) return 'presentation/page';
  if (s.contains('/presentation/widget')) return 'presentation/widget';
  if (s.contains('/flow/') || s.contains('/flow.')) return 'flow';
  if (s.contains('/navigator')) return 'navigator';
  return 'other';
}

List<Map<String, Object?>> _hist(Iterable<int> values, List<int> edges) {
  // edges: lower bounds of each bucket, ascending; last bucket is open.
  final counts = List<int>.filled(edges.length, 0);
  for (final v in values) {
    var i = edges.length - 1;
    while (i > 0 && v < edges[i]) {
      i--;
    }
    counts[i]++;
  }
  return [
    for (var i = 0; i < edges.length; i++)
      {
        'bucket': i == edges.length - 1
            ? '${edges[i]}+'
            : edges[i + 1] - 1 == edges[i]
                ? '${edges[i]}'
                : '${edges[i]}-${edges[i + 1] - 1}',
        'count': counts[i],
      },
  ];
}

Object? _canonical(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _canonical(v[k])};
  }
  if (v is List) return [for (final e in v) _canonical(e)];
  return v;
}

String encodeJson(Map<String, Object?> m) =>
    '${const JsonEncoder.withIndent('  ').convert(_canonical(m))}\n';

String _gitCommit(String root) {
  try {
    final r = Process.runSync('git', ['rev-parse', 'HEAD'],
        workingDirectory: root);
    if (r.exitCode == 0) return (r.stdout as String).trim();
  } on ProcessException {
    // fall through
  }
  return 'unknown';
}

LocResult runLoc(LocOptions o) {
  final root = p.normalize(p.absolute(o.root));
  final genRootAbs =
      o.generatedRoot == null ? null : p.normalize(p.absolute(o.generatedRoot!));
  final files = _walk(root);
  final fallback = _fallbackFiles(root);

  // Modules.
  final modules = <String, _Module>{};
  for (final f in files) {
    if (p.basename(f) != 'pubspec.yaml') continue;
    final dir = p.posix.dirname(f);
    if (dir == '.' || !tiers.contains(dir.split('/').first)) continue;
    final y = _loadYaml(p.join(root, f));
    if (y is! YamlMap) continue;
    final deps = <String>[
      for (final k in ['dependencies', 'dev_dependencies'])
        if (y[k] is YamlMap) ...(y[k] as YamlMap).keys.cast<String>(),
    ];
    final name = (y['name'] ?? p.posix.basename(dir)).toString();
    final testonly = y['testonly'] == true || name == 'mc_test_utils';
    var archetype = 'unknown';
    final manifest = <String, Map<String, Object?>>{};
    final mf = File(p.join(root, dir, '.mcgen/manifest.json'));
    if (mf.existsSync()) {
      final j = jsonDecode(mf.readAsStringSync());
      if (j is Map) {
        if (j['archetype'] is String) archetype = j['archetype'] as String;
        final fm = j['files'];
        if (fm is Map) {
          fm.forEach((k, v) {
            if (v is Map) manifest[k as String] = v.cast<String, Object?>();
          });
        }
      }
    }
    final spec = _loadYaml(p.join(root, dir, 'mcgen.yaml'));
    if (archetype == 'unknown' && spec is YamlMap && spec['archetype'] is String) {
      archetype = spec['archetype'] as String;
    }
    var stem = 'app_localizations';
    final l10n = _loadYaml(p.join(root, dir, 'l10n.yaml'));
    if (l10n is YamlMap && l10n['output-localization-file'] is String) {
      stem = (l10n['output-localization-file'] as String).replaceAll('.dart', '');
    }
    modules[dir] = _Module(dir, name, testonly, deps, archetype, manifest, stem);
  }

  _Module? moduleOf(String f) {
    var d = p.posix.dirname(f);
    while (d != '.' && d.isNotEmpty) {
      if (modules.containsKey(d)) return modules[d];
      d = p.posix.dirname(d);
    }
    return null;
  }

  final fileLoc = <int>[];
  final importsPer = <int>[];
  var toolingLines = 0;
  var toolingFiles = 0;
  var otherFiles = 0;
  final generated = {for (final k in generatorKinds) k: 0, 'other': 0};
  var mixAuthored = 0;
  var mixGenerated = 0;
  final committedGenerated = <String>[];
  var arbKeys = 0;
  var scenarios = 0;
  var fixtureFiles = 0;
  var assetFiles = 0;
  final fileSet = files.toSet();

  String? generatedKind(String f, _Module? m, String Function() content) {
    final s = _genSuffixKind(f);
    if (s == 'json') {
      final c = content();
      return c.contains('RestClient') || c.contains('retrofit') ? 'retrofit' : 'json';
    }
    if (s != null) return s;
    final base = p.posix.basename(f);
    if (m != null) {
      final stem = m.l10nStem;
      if (base == '$stem.dart' ||
          (base.startsWith('${stem}_') && base.endsWith('.dart'))) {
        return 'l10n';
      }
    }
    if (base.endsWith('_test.dart')) {
      final feat =
          '${base.substring(0, base.length - '_test.dart'.length)}.feature';
      if (fileSet.contains(p.posix.join(p.posix.dirname(f), feat))) return 'bdd';
    }
    return null;
  }

  void countGenerated(String kind, String text) {
    final s = scanDart(text);
    generated[kind] = generated[kind]! + s.lines.length;
    mixGenerated += s.mixins;
  }

  for (final f in files) {
    if (genRootAbs != null && p.isWithin(genRootAbs, p.join(root, f))) continue;
    final m = moduleOf(f);
    final segs = f.split('/');
    final top = segs.first;

    // Non-dart inputs.
    if (!f.endsWith('.dart')) {
      final inTier = tiers.contains(top);
      if (!inTier) continue;
      if (f.endsWith('.arb')) {
        final j = jsonDecode(File(p.join(root, f)).readAsStringSync());
        if (j is Map) arbKeys += j.keys.where((k) => !(k as String).startsWith('@')).length;
      } else if (f.endsWith('.feature')) {
        scenarios += File(p.join(root, f))
            .readAsLinesSync()
            .where((l) => RegExp(r'^\s*Scenario( Outline)?:').hasMatch(l))
            .length;
      }
      if (segs.contains('fixtures')) fixtureFiles++;
      if (segs.contains('assets')) assetFiles++;
      continue;
    }

    final inTier = tiers.contains(top);
    final inTool = top == 'tool';
    String? cache;
    String content() => cache ??= File(p.join(root, f)).readAsStringSync();

    final gk = generatedKind(f, m, content);
    if (gk != null || fallback.contains(f)) {
      if (fallback.contains(f)) {
        countGenerated(gk ?? 'other', content());
      } else {
        committedGenerated.add(f);
      }
      otherFiles++;
      continue;
    }
    if (!inTier && !inTool) continue;

    final text = content();
    final scan = scanDart(text);
    if (inTool) {
      toolingLines += scan.lines.length;
      toolingFiles++;
      continue;
    }

    // Tier file: source or test.
    final mod = m;
    final relInMod = mod == null ? f : p.posix.relative(f, from: mod.dir);
    final isTest = (mod?.testonly ?? false) || _testDirs.contains(relInMod.split('/').first);
    final keep = keepRegionLines(text);
    var scaffoldFile = false;
    final entry = mod?.manifest[relInMod];
    if (entry != null && entry['ownership'] != 'ejected') {
      final h = sha256.convert(utf8.encode(stripKeepRegions(text))).toString();
      scaffoldFile = h == entry['hash'];
    }
    var hand = 0;
    var scaf = 0;
    for (final l in scan.lines) {
      if (scaffoldFile && !keep.contains(l)) {
        scaf++;
      } else {
        hand++;
      }
    }
    final target = mod == null
        ? null
        : (isTest ? mod.test : mod.source);
    if (target != null) {
      target.hand += hand;
      target.scaffold += scaf;
    }
    if (mod != null) {
      if (isTest) {
        mod.testFiles++;
      } else {
        mod.libFiles++;
        mod.layers.update(_layerOf(relInMod), (v) => v + hand + scaf,
            ifAbsent: () => hand + scaf);
        mixAuthored += scan.mixins;
        fileLoc.add(hand + scaf);
        importsPer.add(scan.imports);
      }
    }
  }

  // Generated root.
  if (genRootAbs != null && Directory(genRootAbs).existsSync()) {
    for (final f in _walk(genRootAbs)) {
      if (!f.endsWith('.dart')) continue;
      final text = File(p.join(genRootAbs, f)).readAsStringSync();
      final kind = generatedKind(f, null, () => text) ??
          (f.contains('l10n') || p.posix.basename(f).startsWith('app_localizations')
              ? 'l10n'
              : 'other');
      countGenerated(kind, text);
    }
  }

  // Aggregate.
  final mods = modules.values.toList()..sort((a, b) => a.dir.compareTo(b.dir));
  final names = {for (final m in mods) m.name};
  final fanOut = <String, int>{};
  final fanIn = {for (final m in mods) m.name: 0};
  for (final m in mods) {
    final d = m.deps.where((x) => names.contains(x) && x != m.name).toSet();
    fanOut[m.name] = d.length;
    for (final x in d) {
      fanIn[x] = fanIn[x]! + 1;
    }
  }

  int sum(int Function(_Module) f) => mods.fold(0, (a, m) => a + f(m));
  final byTier = <String, Map<String, Object?>>{};
  final byArch = <String, Map<String, Object?>>{};
  void add(Map<String, Map<String, Object?>> into, String k, _Module m) {
    final e = into.putIfAbsent(
        k, () => {'modules': 0, 'source': 0, 'test': 0});
    e['modules'] = (e['modules'] as int) + 1;
    e['source'] = (e['source'] as int) + m.source.total;
    e['test'] = (e['test'] as int) + m.test.total;
  }

  for (final m in mods) {
    add(byTier, m.tier, m);
    add(byArch, m.archetype, m);
  }

  final srcHand = sum((m) => m.source.hand);
  final srcScaf = sum((m) => m.source.scaffold);
  final testHand = sum((m) => m.test.hand);
  final testScaf = sum((m) => m.test.scaffold);
  final failures = <String>[
    if (o.strict)
      for (final f in committedGenerated)
        'committed generated file (D7): $f',
  ];

  final json = <String, Object?>{
    'schema': schemaId,
    'commit': o.commit ?? _gitCommit(root),
    'rule': 'D8',
    if (o.stamp != null) 'stamp': o.stamp,
    'totals': {
      'source': {'hand': srcHand, 'scaffold': srcScaf},
      'test': {'hand': testHand, 'scaffold': testScaf},
      'generated': generated,
      'tooling': toolingLines,
      'packages': mods.length,
      'files': {
        'lib': sum((m) => m.libFiles),
        'test': sum((m) => m.testFiles),
        'other': otherFiles + toolingFiles,
      },
    },
    'non_dart': {
      'arb_keys': arbKeys,
      'feature_scenarios': scenarios,
      'fixture_files': fixtureFiles,
      'asset_files': assetFiles,
    },
    'excluded_committed_generated': [...committedGenerated]..sort(),
    'by_tier': byTier,
    'by_archetype': byArch,
    'modules': [
      for (final m in mods)
        {
          'name': m.name,
          'path': m.dir,
          'tier': m.tier,
          'archetype': m.archetype,
          'testonly': m.testonly,
          'source': {'hand': m.source.hand, 'scaffold': m.source.scaffold},
          'test': {'hand': m.test.hand, 'scaffold': m.test.scaffold},
          'layers': {for (final k in m.layers.keys) k: m.layers[k]},
        },
    ],
    'histograms': {
      'file_loc': _hist(fileLoc, [0, 50, 100, 200, 400, 800]),
      'imports_per_file': _hist(importsPer, [0, 1, 6, 11, 21]),
      'pkg_fan_out': _hist(fanOut.values, [0, 1, 2, 3, 6, 11, 21]),
      'pkg_fan_in': _hist(fanIn.values, [0, 1, 2, 3, 6, 11, 21]),
    },
    'mixins': {'authored': mixAuthored, 'generated': mixGenerated},
    'gates': {'rung': null, 'pass': failures.isEmpty, 'failures': failures},
  };
  return LocResult(json, _markdown(json), failures);
}

String _markdown(Map<String, Object?> j) {
  final t = j['totals'] as Map;
  final src = t['source'] as Map;
  final tst = t['test'] as Map;
  final gen = t['generated'] as Map;
  final b = StringBuffer()
    ..writeln('# LOC report (`$schemaId`, rule D8)')
    ..writeln()
    ..writeln('Commit: `${j['commit']}`')
    ..writeln()
    ..writeln('## Totals')
    ..writeln()
    ..writeln('| Bucket | hand | scaffold | total |')
    ..writeln('|---|---:|---:|---:|')
    ..writeln(
        '| source (D8) | ${src['hand']} | ${src['scaffold']} | ${(src['hand'] as int) + (src['scaffold'] as int)} |')
    ..writeln(
        '| test | ${tst['hand']} | ${tst['scaffold']} | ${(tst['hand'] as int) + (tst['scaffold'] as int)} |')
    ..writeln()
    ..writeln('Tooling: ${t['tooling']} | Packages: ${t['packages']} | '
        'Files: ${(t['files'] as Map)['lib']} lib, ${(t['files'] as Map)['test']} test, ${(t['files'] as Map)['other']} other')
    ..writeln()
    ..writeln('Generated: ${gen.entries.map((e) => '${e.key}=${e.value}').join(', ')}')
    ..writeln()
    ..writeln('## Per tier')
    ..writeln()
    ..writeln('| Tier | modules | source | test |')
    ..writeln('|---|---:|---:|---:|');
  void table(Map m) {
    for (final k in (m.keys.toList()..sort())) {
      final e = m[k] as Map;
      b.writeln('| $k | ${e['modules']} | ${e['source']} | ${e['test']} |');
    }
  }

  table(j['by_tier'] as Map);
  b
    ..writeln()
    ..writeln('## Per archetype')
    ..writeln()
    ..writeln('| Archetype | modules | source | test |')
    ..writeln('|---|---:|---:|---:|');
  table(j['by_archetype'] as Map);
  final mods = (j['modules'] as List).cast<Map>().toList()
    ..sort((a, c) {
      int tot(Map m) =>
          ((m['source'] as Map)['hand'] as int) +
          ((m['source'] as Map)['scaffold'] as int);
      final d = tot(c).compareTo(tot(a));
      return d != 0 ? d : (a['path'] as String).compareTo(c['path'] as String);
    });
  b
    ..writeln()
    ..writeln('## Top 20 modules by source LOC')
    ..writeln()
    ..writeln('| Module | path | source |')
    ..writeln('|---|---|---:|');
  for (final m in mods.take(20)) {
    final s = m['source'] as Map;
    b.writeln('| ${m['name']} | ${m['path']} | ${(s['hand'] as int) + (s['scaffold'] as int)} |');
  }
  b
    ..writeln()
    ..writeln('## Histograms');
  (j['histograms'] as Map).forEach((k, v) {
    b
      ..writeln()
      ..writeln('`$k`: ${(v as List).map((e) => '${e['bucket']}:${e['count']}').join(' ')}');
  });
  final g = j['gates'] as Map;
  b
    ..writeln()
    ..writeln('## Gates')
    ..writeln()
    ..writeln('pass: ${g['pass']}');
  for (final f in g['failures'] as List) {
    b.writeln('- FAIL: $f');
  }
  return b.toString();
}
