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
    this.includeUntracked = false,
  });

  final String root;
  final String? generatedRoot;
  final bool strict;
  final String? stamp;
  final String? commit;

  /// Also count files git does not track (default: tracked files only).
  final bool includeUntracked;
}

class LocResult {
  LocResult(this.json, this.markdown, this.failures, this.warnings);
  final Map<String, Object?> json;
  final String markdown;

  /// Fatal under `--strict` (committed generated files, dropped input, ...).
  final List<String> failures;
  final List<String> warnings;
}

class _Module {
  _Module(this.dir, this.name, this.testonly, this.deps, this.archetype,
      this.manifest, this.l10nStem, this.l10nDir);
  final String dir; // relative, posix
  final String name;
  final bool testonly;
  final List<String> deps;
  final String archetype;
  final Map<String, Map<String, Object?>> manifest;
  final String l10nStem;
  final String? l10nDir; // relative to the module; null when no l10n.yaml
  bool synthetic = false;
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

/// Tracked files via `git ls-files` (plus untracked when asked). Returns null
/// when [root] is not inside a git work tree.
List<String>? _gitFiles(String root, bool includeUntracked) {
  try {
    final args = [
      'ls-files',
      '-z',
      '--cached',
      if (includeUntracked) ...['--others', '--exclude-standard'],
    ];
    final r = Process.runSync('git', args,
        workingDirectory: root, stdoutEncoding: utf8);
    if (r.exitCode != 0) return null;
    final out = (r.stdout as String)
        .split('\u0000')
        .where((x) => x.isNotEmpty)
        .toSet()
        .where((x) => File(p.join(root, x)).existsSync())
        .toList()
      ..sort();
    return out;
  } on ProcessException {
    return null;
  }
}

String _read(String path) =>
    File(path).readAsStringSync(encoding: const Utf8Codec(allowMalformed: true));

String _genKindOfHeader(String name) {
  if (name.contains('Retrofit')) return 'retrofit';
  if (name.contains('Freezed')) return 'freezed';
  if (name.contains('Injectable')) return 'injectable';
  if (name.contains('GoRouter')) return 'go_router';
  if (name.contains('Json')) return 'json';
  return 'other';
}

/// Splits the counted lines of a combined `.g.dart` by source_gen section
/// header (`// ****`, `// <Name>Generator`, `// ****`). Lines before the first
/// header go to the first section; a file with no header is all `json`.
Map<String, int> _splitGenerated(
    String kind, String path, String text, FileScan scan) {
  if (!path.endsWith('.g.dart')) return {kind: scan.lines.length};
  final lines = text.split('\n');
  final stars = RegExp(r'^// \*{20,}\s*$');
  final name = RegExp(r'^// (\w+)\s*$');
  final headers = <(int, String)>[]; // (1-based line, kind)
  for (var i = 0; i + 2 < lines.length; i++) {
    final n = name.firstMatch(lines[i + 1]);
    if (stars.hasMatch(lines[i]) && n != null && stars.hasMatch(lines[i + 2])) {
      headers.add((i + 1, _genKindOfHeader(n.group(1)!)));
    }
  }
  if (headers.isEmpty) return {'json': scan.lines.length};
  final out = <String, int>{};
  for (final l in scan.lines) {
    var k = headers.first.$2;
    for (final h in headers) {
      if (h.$1 <= l) k = h.$2;
    }
    out[k] = (out[k] ?? 0) + 1;
  }
  return out;
}

LocResult runLoc(LocOptions o) {
  final root = p.normalize(p.absolute(o.root));
  final genRootAbs =
      o.generatedRoot == null ? null : p.normalize(p.absolute(o.generatedRoot!));
  final warnings = <String>[];
  final problems = <String>[]; // warnings that fail --strict
  void warn(String m, {bool fatal = false}) {
    warnings.add(m);
    if (fatal) problems.add(m);
  }

  var files = _gitFiles(root, o.includeUntracked);
  if (files == null) {
    warn('$root is not in a git work tree: walked the filesystem, so '
        'untracked files are counted');
    files = _walk(root);
  }
  final fallback = _fallbackFiles(root);

  // Modules.
  final modules = <String, _Module>{};
  for (final f in files) {
    if (p.basename(f) != 'pubspec.yaml') continue;
    final dir = p.posix.dirname(f);
    if (dir == '.' || !tiers.contains(dir.split('/').first)) continue;
    final y = _loadYaml(p.join(root, f));
    if (y is! YamlMap) {
      warn('unparseable pubspec.yaml (module skipped): $f', fatal: true);
      continue;
    }
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
      try {
        final j = jsonDecode(_read(mf.path));
        if (j is! Map) throw const FormatException('not a JSON object');
        if (j['archetype'] is String) archetype = j['archetype'] as String;
        final fm = j['files'];
        if (fm is Map) {
          fm.forEach((k, v) {
            if (v is Map) manifest[k as String] = v.cast<String, Object?>();
          });
        }
      } on FormatException catch (e) {
        manifest.clear();
        warn(
            'malformed $dir/.mcgen/manifest.json (treated as no manifest): ${e.message}',
            fatal: true);
      }
    }
    final spec = _loadYaml(p.join(root, dir, 'mcgen.yaml'));
    if (archetype == 'unknown' &&
        spec is YamlMap &&
        spec['archetype'] is String) {
      archetype = spec['archetype'] as String;
    }
    var stem = 'app_localizations';
    String? l10nDir;
    final l10nFile = File(p.join(root, dir, 'l10n.yaml'));
    if (l10nFile.existsSync()) {
      final l10n = _loadYaml(l10nFile.path);
      l10nDir = 'lib/l10n';
      if (l10n is YamlMap) {
        if (l10n['output-localization-file'] is String) {
          stem = (l10n['output-localization-file'] as String)
              .replaceAll('.dart', '');
        }
        final od = l10n['output-dir'] ?? l10n['arb-dir'];
        if (od is String) l10nDir = p.posix.normalize(od);
      }
    }
    modules[dir] =
        _Module(dir, name, testonly, deps, archetype, manifest, stem, l10nDir);
  }

  _Module? moduleOf(String f) {
    var d = p.posix.dirname(f);
    while (d != '.' && d.isNotEmpty) {
      if (modules.containsKey(d)) return modules[d];
      d = p.posix.dirname(d);
    }
    return null;
  }

  final unowned = <String, _Module>{};
  _Module unownedFor(String tier) => unowned.putIfAbsent(
      tier,
      () => _Module(tier, '(unowned:$tier)', false, const [], 'unknown', {},
          'app_localizations', null)
        ..synthetic = true);

  final fileLoc = <int>[];
  final importsPer = <int>[];
  var toolingLines = 0;
  var toolingFiles = 0;
  var otherFiles = 0;
  final generated = {for (final k in generatorKinds) k: 0, 'other': 0};
  var mixAuthored = 0;
  var mixGenerated = 0;
  var withApplications = 0;
  final committedGenerated = <String>[];
  var arbKeys = 0;
  var scenarios = 0;
  var fixtureFiles = 0;
  var assetFiles = 0;
  final fileSet = files.toSet();

  /// Generator kind of [f] by name, or null. [checkDir] restricts l10n to the
  /// module's configured output dir (not applicable under a generated root).
  String? generatedKind(String f, _Module? m, {bool checkDir = true}) {
    final s = _genSuffixKind(f);
    if (s != null) return s;
    final base = p.posix.basename(f);
    if (m != null && m.l10nDir != null) {
      final stem = m.l10nStem;
      final rel = p.posix.relative(f, from: m.dir);
      final inDir = !checkDir ||
          p.posix.dirname(rel) == m.l10nDir ||
          p.posix.isWithin(m.l10nDir!, rel);
      if (inDir &&
          (base == '$stem.dart' ||
              (base.startsWith('${stem}_') && base.endsWith('.dart')))) {
        return 'l10n';
      }
    }
    if (base.endsWith('_test.dart')) {
      final feat =
          '${base.substring(0, base.length - '_test.dart'.length)}.feature';
      if (fileSet.contains(p.posix.join(p.posix.dirname(f), feat))) {
        return 'bdd';
      }
    }
    return null;
  }

  void countGenerated(String kind, String f, String text) {
    final s = scanDart(text);
    _splitGenerated(kind, f, text, s).forEach((k, v) {
      generated[k] = generated[k]! + v;
    });
    mixGenerated += s.mixins;
  }

  for (final f in files) {
    if (genRootAbs != null && p.isWithin(genRootAbs, p.join(root, f))) continue;
    final m = moduleOf(f);
    final segs = f.split('/');
    final top = segs.first;

    // Non-dart inputs.
    if (!f.endsWith('.dart')) {
      if (!tiers.contains(top)) continue;
      if (f.endsWith('.arb')) {
        try {
          final j = jsonDecode(_read(p.join(root, f)));
          if (j is! Map) throw const FormatException('not a JSON object');
          arbKeys += j.keys.where((k) => !(k as String).startsWith('@')).length;
        } on FormatException catch (e) {
          warn('malformed .arb (keys not counted): $f: ${e.message}',
              fatal: true);
        }
      } else if (f.endsWith('.feature')) {
        scenarios += _read(p.join(root, f))
            .split('\n')
            .where((l) => RegExp(r'^\s*Scenario( Outline)?:').hasMatch(l))
            .length;
      }
      if (segs.contains('fixtures')) fixtureFiles++;
      if (segs.contains('assets')) assetFiles++;
      continue;
    }

    final inTier = tiers.contains(top);
    final inTool = top == 'tool';
    final gk = generatedKind(f, m);
    if (gk != null || fallback.contains(f)) {
      if (fallback.contains(f)) {
        countGenerated(gk ?? 'other', f, _read(p.join(root, f)));
      } else {
        committedGenerated.add(f);
      }
      otherFiles++;
      continue;
    }
    if (!inTier && !inTool) continue;

    final text = _read(p.join(root, f));
    final scan = scanDart(text);
    if (inTool) {
      toolingLines += scan.lines.length;
      toolingFiles++;
      continue;
    }

    // Tier file: source or test. Files outside any module are not dropped:
    // they go to a synthetic per-tier module and raise a fatal warning.
    var mod = m;
    if (mod == null) {
      mod = unownedFor(top);
      warn('dart file outside any module (counted in ${mod.name}): $f',
          fatal: true);
    }
    final relInMod = p.posix.relative(f, from: mod.dir);
    final isTest =
        mod.testonly || _testDirs.contains(relInMod.split('/').first);
    final keep = keepRegionLines(text);
    var scaffoldFile = false;
    final entry = mod.manifest[relInMod];
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
    final target = isTest ? mod.test : mod.source;
    target.hand += hand;
    target.scaffold += scaf;
    if (isTest) {
      mod.testFiles++;
    } else {
      mod.libFiles++;
      mod.layers.update(_layerOf(relInMod), (v) => v + hand + scaf,
          ifAbsent: () => hand + scaf);
      mixAuthored += scan.mixins;
      withApplications += scan.withApplications;
      fileLoc.add(hand + scaf);
      importsPer.add(scan.imports);
    }
  }

  // Generated root: only files of a known generator kind under a first-party
  // tier path (so `external/` and source copies are excluded).
  if (genRootAbs != null && Directory(genRootAbs).existsSync()) {
    for (final f in _walk(genRootAbs)) {
      if (!f.endsWith('.dart') || !tiers.contains(f.split('/').first)) continue;
      final kind = generatedKind(f, moduleOf(f), checkDir: false);
      if (kind == null) continue;
      countGenerated(kind, f, _read(p.join(genRootAbs, f)));
    }
  }

  // Aggregate.
  final real = modules.values.toList()..sort((a, b) => a.dir.compareTo(b.dir));
  final syn = unowned.values.toList()..sort((a, b) => a.dir.compareTo(b.dir));
  final mods = [...real, ...syn];
  final names = {for (final m in real) m.name};
  final fanOut = <String, int>{};
  final fanIn = {for (final m in real) m.name: 0};
  for (final m in real) {
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
    final e =
        into.putIfAbsent(k, () => {'modules': 0, 'source': 0, 'test': 0});
    if (!m.synthetic) e['modules'] = (e['modules'] as int) + 1;
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
    if (o.strict) ...[
      for (final f in committedGenerated) 'committed generated file (D7): $f',
      ...problems,
    ],
  ];
  warnings.sort();

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
      'packages': real.length,
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
    'warnings': warnings,
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
          'synthetic': m.synthetic,
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
    'mixins': {
      'authored': mixAuthored,
      'generated': mixGenerated,
      'with_applications': withApplications,
    },
    'gates': {'rung': null, 'pass': failures.isEmpty, 'failures': failures},
  };
  return LocResult(json, _markdown(json), failures, warnings);
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
  final w = j['warnings'] as List;
  if (w.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Warnings')
      ..writeln();
    for (final x in w) {
      b.writeln('- $x');
    }
  }
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
