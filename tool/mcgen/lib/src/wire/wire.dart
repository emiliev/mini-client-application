// `mcgen wire [--check]` (plan 02 section 2.8, T-0074, ADR-0018): the shared
// glue, regenerated from every spec and package, never edited by hand. A
// merge conflict in one of these files is resolved by running wire again.
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

import 'dart:io';

import 'package:mcgen/src/core/format.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:mcgen/src/wire/app.dart';
import 'package:mcgen/src/wire/flow_scope.dart';
import 'package:mcgen/src/wire/groups.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One file wire owns: what it would write, and what is there.
class WireOutput {
  WireOutput(this.path, this.content, this.before, {this.owned = false});

  /// Root-relative.
  final String path;
  final String content;
  final String? before;

  /// Written once (a navigator skeleton), then the file is the engineer's.
  final bool owned;

  bool get changed => owned ? before == null : content != before;

  String get firstDifference {
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

String? _read(String root, String rel) {
  final f = File(p.join(root, rel));
  return f.existsSync() ? f.readAsStringSync() : null;
}

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

/// Everything wire owns under [root], given the specs there.
List<WireOutput> wireAll(
  String root,
  List<ModuleSpec> specs,
  DartFormatter formatter, {
  WireConfig config = const WireConfig(),
}) {
  final index = RepoIndex.scan(root);
  final groups = planGroups(
    root,
    index,
    specs,
    order: config.groups,
    domains: config.domains,
    locations: appLocationIdMethods(root),
  );
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
  final locations = generatedLocations(groups);
  dart[generatedLocationsPath] = locations;

  // Flow scopes: every feature package with a flow and a DI initializer,
  // plus the generated modules not on disk yet are covered once written.
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

  final workspace = _read(root, 'pubspec.yaml');
  if (workspace != null) {
    out.add(
      WireOutput(
        'pubspec.yaml',
        workspaceMembers(workspace, [
          for (final pkg in index.packages) pkg.dir,
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
  return out;
}

int runWire(
  String root,
  List<ModuleSpec> specs,
  DartFormatter formatter, {
  WireConfig config = const WireConfig(),
  required bool check,
  required StringSink out,
  required StringSink err,
}) {
  final List<WireOutput> outputs;
  try {
    outputs = wireAll(root, specs, formatter, config: config);
  } on StateError catch (x) {
    err.writeln('mcgen wire: ${x.message}');
    return 1;
  }
  var stale = 0;
  for (final o in outputs) {
    if (!o.changed) {
      out.writeln('${o.path}: up to date${o.owned ? ' (owned)' : ''}');
      continue;
    }
    stale++;
    if (check) {
      err.writeln('${o.path}: out of date, ${o.firstDifference}');
    } else {
      File(p.join(root, o.path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(o.content);
      out.writeln('${o.path}: wrote${o.owned ? ' (owned from now on)' : ''}');
    }
  }
  out.writeln(
    'mcgen wire: ${outputs.length} file(s), '
    '${check ? '$stale out of date' : '$stale written'}',
  );
  return check && stale > 0 ? 1 : 0;
}
