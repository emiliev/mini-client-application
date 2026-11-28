// `mcgen wire [--check] [--force]` (plan 02 section 2.8, T-0074, ADR-0018):
// the shared glue, regenerated from every spec and package, never edited by
// hand. A merge conflict in one of these files is resolved by running wire
// again.
//
// Wire-owned (F-0074 lists what is not, and why):
//   - every feature's `lib/src/di/flow_scope.dart` (R17), the doc comment
//     above the list carried over;
//   - the root pubspec's `workspace:` members under app/, feature/ and
//     utility/;
//   - the app's wiring list (`app/mini_client/lib/src/wirings.dart`: DI
//     initializers, routes, catalogue entries), its `*_wiring` pubspec deps
//     and `app/mini_client/wirings.bzl`;
//   - each generated wiring group (`app/wiring/<group>_wiring/`) and
//     `app_core`'s `GeneratedLocations`.
//
// A generated group's `.mcgen/wire.json` records the files wire wrote there
// and the first-write hash of each owned one (navigator skeletons). What a
// later run no longer generates is deleted: a managed file always, an owned
// one only while it is as wire wrote it. An owned file someone edited stops
// the run (nothing is written) unless `--force`.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mcgen/src/core/format.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/wire/app.dart';
import 'package:mcgen/src/wire/flow_scope.dart';
import 'package:mcgen/src/wire/groups.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One file wire owns: what it would write (or delete), and what is there.
class WireOutput {
  WireOutput(
    this.path,
    this.content,
    this.before, {
    this.owned = false,
    this.delete = false,
  });

  /// Root-relative.
  final String path;
  final String content;
  final String? before;

  /// Written once (a navigator skeleton), then the file is the engineer's.
  final bool owned;

  /// A file wire wrote before and no longer generates.
  final bool delete;

  bool get changed => delete
      ? before != null
      : owned
      ? before == null
      : content != before;

  String get firstDifference {
    if (delete) return 'no longer generated: would delete';
    final a = content.split('\n');
    final b = (before ?? '').split('\n');
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : '<end of file>';
      final y = i < b.length ? b[i] : '<end of file>';
      if (x != y) return 'line ${i + 1}: "$x" | "$y"';
    }
    return 'identical';
  }
}

/// Everything one run of wire would do.
class WireResult {
  WireResult(this.outputs, {this.warnings = const [], this.blocked = const []});

  final List<WireOutput> outputs;

  /// What wire tells the user without failing (flows it left unwired).
  final List<String> warnings;

  /// Owned files wire no longer generates and someone edited: wire deletes
  /// them only with `--force`.
  final List<String> blocked;
}

String? _read(String root, String rel) {
  final f = File(p.join(root, rel));
  return f.existsSync() ? f.readAsStringSync() : null;
}

String _hash(String text) => sha256.convert(utf8.encode(text)).toString();

/// `tool/mcgen/mcgen.yaml`'s `wire:` block.
class WireConfig {
  const WireConfig({this.groups = const [], this.domains = const {}});

  factory WireConfig.load(String configPath) {
    final y = loadYaml(File(configPath).readAsStringSync());
    final w = y is YamlMap ? y['wire'] : null;
    if (w is! YamlMap) return const WireConfig();
    final groups = w['groups'];
    final domains = w['domains'];
    return WireConfig(
      groups: groups is YamlList ? [for (final g in groups) '$g'] : const [],
      domains: domains is YamlMap
          ? {for (final e in domains.entries) '${e.key}': '${e.value}'}
          : const {},
    );
  }

  /// The app's groups, in the order it lists them.
  final List<String> groups;

  /// Feature domain -> its group, where the names differ.
  final Map<String, String> domains;
}

/// A generated group's `.mcgen/wire.json`: the files wire wrote there
/// (group-relative), and each owned file's first-write hash.
class WireMarker {
  WireMarker(this.group, this.modules, this.managed, this.owned);

  factory WireMarker.parse(String text, String path) {
    final Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException catch (x) {
      throw StateError('$path: not JSON: ${x.message}');
    }
    if (j is! Map<String, Object?>)
      throw StateError('$path: not a JSON object');
    List<String> strings(Object? v) =>
        v is List ? [for (final x in v) '$x'] : const [];
    final owned = j['owned'];
    return WireMarker(
      '${j['group']}',
      strings(j['modules']),
      strings(j['managed']),
      owned is Map
          ? {for (final e in owned.entries) '${e.key}': '${e.value}'}
          // A marker from before T-0074's review round listed owned paths
          // with no hash: every one counts as edited, so none is deleted.
          : {for (final o in strings(owned)) o: ''},
    );
  }

  final String group;
  final List<String> modules;
  final List<String> managed;
  final Map<String, String> owned;

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert({
        'generator': 'mcgen wire',
        'group': group,
        'managed': managed,
        'modules': modules,
        'owned': owned,
      })}\n';
}

/// The markers of the generated groups on disk, by group directory.
Map<String, WireMarker> _markers(String root) {
  final out = <String, WireMarker>{};
  final wiring = Directory(p.join(root, 'app', 'wiring'));
  if (!wiring.existsSync()) return out;
  for (final d in wiring.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
    if (d is! Directory) continue;
    final rel = 'app/wiring/${p.basename(d.path)}';
    final text = _read(root, '$rel/$wireMarker');
    if (text != null) out[rel] = WireMarker.parse(text, '$rel/$wireMarker');
  }
  return out;
}

/// Everything wire owns under [root], given the specs there. With [only]
/// (root-relative package directories), just those packages' own files
/// (their flow scopes): a module generated alone, outside the app.
WireResult wireAll(
  String root,
  List<ModuleSpec> specs,
  DartFormatter formatter, {
  WireConfig config = const WireConfig(),
  List<String>? only,
}) {
  final index = RepoIndex.scan(root);
  if (only != null) {
    final dart = <String, String>{};
    for (final pkg in index.packages) {
      if (!only.contains(pkg.dir) || pkg.tier != Tier.feature) continue;
      final abs = p.join(root, pkg.dir);
      if (!hasFlowScope(abs)) continue;
      final rel = '${pkg.dir}/$flowScopePath';
      dart[rel] = flowScopeFile(
        pkg.name,
        rootImports(pkg.name, abs, root),
        existing: _read(root, rel),
      );
    }
    return WireResult([
      for (final e in formatter.formatAll(dart).entries)
        WireOutput(e.key, e.value, _read(root, e.key)),
    ]);
  }
  final groups = planGroups(
    root,
    index,
    specs,
    order: config.groups,
    domains: config.domains,
    locations: appLocationIdMethods(root),
  );
  final previous = _markers(root);
  final out = <WireOutput>[];
  final dart = <String, String>{};
  final owned = <String>{};

  // Generated groups first: they add packages the rest must see.
  for (final g in groups.generated) {
    for (final f in g.files.entries) {
      if (f.key.endsWith('.dart')) {
        dart[f.key] = f.value;
      } else {
        out.add(WireOutput(f.key, f.value, _read(root, f.key)));
      }
    }
    owned.addAll(g.owned);
  }
  dart[generatedLocationsPath] = generatedLocations(groups);

  // Flow scopes: every feature package with a flow and a DI initializer.
  for (final pkg in index.packages) {
    if (pkg.tier != Tier.feature) continue;
    final abs = p.join(root, pkg.dir);
    if (!hasFlowScope(abs)) continue;
    final rel = '${pkg.dir}/$flowScopePath';
    dart[rel] = flowScopeFile(
      pkg.name,
      rootImports(pkg.name, abs, root),
      existing: _read(root, rel),
    );
  }

  dart[appWiringsPath] = appWirings(groups);
  final formatted = formatter.formatAll(dart);
  for (final e in formatted.entries) {
    out.add(
      WireOutput(
        e.key,
        e.value,
        _read(root, e.key),
        owned: owned.contains(e.key),
      ),
    );
  }

  // Each generated group's marker, and what its previous marker lists that
  // nothing generates any more.
  final blocked = <String>[];
  final generatedDirs = <String>{};
  for (final g in groups.generated) {
    generatedDirs.add(g.dir);
    final old = previous[g.dir];
    String rel(String path) => p.posix.relative(path, from: g.dir);
    final managed = {
      for (final f in g.files.keys)
        if (!g.owned.contains(f)) rel(f),
      'BUILD.bazel',
      wireMarker,
    }.toList()..sort();
    final ownedHashes = {
      for (final f in (g.owned.toList()..sort()))
        rel(f): old?.owned[rel(f)] ?? _hash(formatted[f] ?? g.files[f]!),
    };
    final marker = WireMarker(
      g.name,
      [for (final f in g.flows) f.module],
      managed,
      ownedHashes,
    );
    out.add(
      WireOutput(
        '${g.dir}/$wireMarker',
        marker.encode(),
        _read(root, '${g.dir}/$wireMarker'),
      ),
    );
    if (old != null) {
      _orphans(
        root,
        g.dir,
        old,
        managed.toSet(),
        ownedHashes.keys.toSet(),
        out,
        blocked,
      );
    }
  }
  for (final e in previous.entries) {
    if (generatedDirs.contains(e.key)) continue;
    // A group with no flow left: everything wire wrote there goes.
    _orphans(root, e.key, e.value, const {}, const {}, out, blocked);
  }
  final removedDirs = previous.keys.toSet().difference(generatedDirs);

  final workspace = _read(root, 'pubspec.yaml');
  if (workspace != null) {
    out.add(
      WireOutput(
        'pubspec.yaml',
        workspaceMembers(workspace, [
          for (final pkg in index.packages)
            if (!removedDirs.contains(pkg.dir)) pkg.dir,
          for (final g in groups.generated) g.dir,
        ]),
        workspace,
      ),
    );
  }
  final appPubspec = _read(root, appPubspecPath);
  if (appPubspec != null) {
    out.add(
      WireOutput(
        appPubspecPath,
        appWiringDeps(appPubspec, groups),
        appPubspec,
      ),
    );
  }
  out.add(
    WireOutput(
      appWiringsBzlPath,
      appWiringsBzl(groups),
      _read(root, appWiringsBzlPath),
    ),
  );
  out.sort((a, b) => a.path.compareTo(b.path));
  return WireResult(out, warnings: groups.warnings, blocked: blocked);
}

void _orphans(
  String root,
  String dir,
  WireMarker old,
  Set<String> managed,
  Set<String> owned,
  List<WireOutput> out,
  List<String> blocked,
) {
  for (final m in old.managed) {
    if (managed.contains(m)) continue;
    final path = '$dir/$m';
    final before = _read(root, path);
    if (before != null) out.add(WireOutput(path, '', before, delete: true));
  }
  for (final e in old.owned.entries) {
    if (owned.contains(e.key)) continue;
    final path = '$dir/${e.key}';
    final before = _read(root, path);
    if (before == null) continue;
    if (_hash(before) != e.value) blocked.add(path);
    out.add(WireOutput(path, '', before, owned: true, delete: true));
  }
}

/// Deletes [rel] and then each parent directory it leaves empty, up to
/// `app/wiring`.
void _delete(String root, String rel) {
  File(p.join(root, rel)).deleteSync();
  var dir = p.dirname(rel);
  while (dir.startsWith('app/wiring/')) {
    final d = Directory(p.join(root, dir));
    if (!d.existsSync() || d.listSync().isNotEmpty) break;
    d.deleteSync();
    dir = p.dirname(dir);
  }
}

int runWire(
  String root,
  List<ModuleSpec> specs,
  DartFormatter formatter, {
  WireConfig config = const WireConfig(),
  List<String>? only,
  bool force = false,
  required bool check,
  required StringSink out,
  required StringSink err,
}) {
  final WireResult result;
  try {
    result = wireAll(root, specs, formatter, config: config, only: only);
  } on StateError catch (x) {
    err.writeln('mcgen wire: ${x.message}');
    return 1;
  }
  for (final w in result.warnings) {
    err.writeln('warning: $w');
  }
  if (result.blocked.isNotEmpty && !force) {
    err.writeln(
      'mcgen wire: ${check ? '' : 'refusing to write anything: '}'
      '${result.blocked.length} owned file(s) no flow generates any more, '
      'edited since wire wrote them:',
    );
    for (final b in result.blocked) {
      err.writeln('  orphan-owned: $b');
    }
    err.writeln(
      'remedies: move the code you need elsewhere and delete the file, or '
      'pass --force to delete it',
    );
    return 1;
  }
  var stale = 0;
  for (final o in result.outputs) {
    if (!o.changed) {
      out.writeln('${o.path}: up to date${o.owned ? ' (owned)' : ''}');
      continue;
    }
    stale++;
    final forced = result.blocked.contains(o.path)
        ? ' (forced over an edit)'
        : '';
    if (check) {
      err.writeln('${o.path}: out of date, ${o.firstDifference}');
    } else if (o.delete) {
      _delete(root, o.path);
      out.writeln('${o.path}: deleted (no longer generated)$forced');
    } else {
      File(p.join(root, o.path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(o.content);
      out.writeln('${o.path}: wrote${o.owned ? ' (owned from now on)' : ''}');
    }
  }
  out.writeln(
    'mcgen wire: ${result.outputs.length} file(s), '
    '${check ? '$stale out of date' : '$stale written or deleted'}',
  );
  return check && stale > 0 ? 1 : 0;
}
