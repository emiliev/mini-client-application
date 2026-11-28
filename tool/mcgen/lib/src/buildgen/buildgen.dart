// `mcgen buildgen [--check]` (plan 02 section 2.8, T-0074, ADR-0018): the
// BUILD.bazel of every package buildgen covers, from its files.
//
// Covered: every feature package (`feature/**`) and every wiring group
// `mcgen wire` generates. Not covered yet (F-0074): utility packages (no
// archetype covers one), the hand-written wirings, app_core, the app and
// the sandbox.

import 'dart:io';

import 'package:mcgen/src/buildgen/adopt.dart';
import 'package:mcgen/src/buildgen/feature_build.dart';
import 'package:mcgen/src/buildgen/starlark.dart';
import 'package:mcgen/src/buildgen/wiring_build.dart';
import 'package:mcgen/src/core/repo.dart';
import 'package:mcgen/src/core/spec/spec.dart';
import 'package:path/path.dart' as p;

/// One BUILD file buildgen writes.
class BuildOutput {
  const BuildOutput(this.path, this.content, this.before);

  /// Root-relative.
  final String path;
  final String content;

  /// The file on disk, or null.
  final String? before;

  bool get changed => content != before;

  /// `line N: generated | on disk` for the first line that differs.
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

/// Generated wiring groups' directories, for [buildAll]: what `mcgen wire`
/// writes (a `.mcgen/wire.json` marker in the package).
bool isGeneratedWiring(String dir) =>
    File(p.join(dir, '.mcgen', 'wire.json')).existsSync();

/// The default header of a BUILD file buildgen writes for the first time.
String defaultHeader(String name, String kind) =>
    '# $name: $kind. Written by `mcgen buildgen` from the package\'s files\n'
    '# (T-0074, ADR-0018); regenerate it, never edit it by hand. Comments above\n'
    '# a statement, items marked `# keep` and the `# mcgen:keep build` region at\n'
    '# the end are yours; everything else is buildgen\'s.\n'
    '# No per-package analysis_options.yaml: the root file applies (F-0021).\n';

/// The BUILD files of every covered package under [root], or of the package
/// directories [only] (root-relative) when given.
///
/// With [adopt], a file on disk is first brought into the canonical form
/// (`adoptBuild`): kept items marked, other statements moved into the hand
/// region.
List<BuildOutput> buildAll(
  String root, {
  List<String>? only,
  bool adopt = false,
}) {
  final index = RepoIndex.scan(root);
  String label(String package) {
    final hits = index.named(package);
    return hits.isEmpty ? '@pub_deps//:$package' : '//${hits.first.dir}';
  }

  final out = <BuildOutput>[];
  for (final pkg in index.packages) {
    if (only != null && !only.contains(pkg.dir)) continue;
    final abs = p.join(root, pkg.dir);
    final rel = '${pkg.dir}/BUILD.bazel';
    final file = File(p.join(root, rel));
    final before = file.existsSync() ? file.readAsStringSync() : null;
    BuildFile? existing;
    if (before != null) {
      try {
        existing = BuildFile.parse(before);
      } on FormatException catch (x) {
        throw StateError('$rel: ${x.message}');
      }
    }
    String Function(BuildFile?)? render;
    if (pkg.tier == Tier.feature) {
      final model = FeaturePackage.read(pkg.name, abs);
      render = (f) => featureBuild(
        model,
        f,
        label: label,
        header: defaultHeader(pkg.name, 'a feature package'),
      );
    } else if (pkg.tier == Tier.app && isGeneratedWiring(abs)) {
      final model = WiringPackage.read(pkg.name, abs);
      render = (f) => wiringBuild(
        model,
        f,
        label: label,
        header: defaultHeader(pkg.name, 'a wiring group mcgen wire generates'),
      );
    }
    if (render == null) continue;
    final content = adopt && before != null
        ? adoptBuild(before, render)
        : render(existing);
    out.add(BuildOutput(rel, content, before));
  }
  return out;
}

/// Runs buildgen: 0 when up to date (or written), 1 when `--check` finds a
/// difference.
int runBuildgen(
  String root, {
  required bool check,
  bool adopt = false,
  List<String>? only,
  required StringSink out,
  required StringSink err,
}) {
  final outputs = buildAll(root, only: only, adopt: adopt);
  var stale = 0;
  for (final o in outputs) {
    if (!o.changed) {
      out.writeln('${o.path}: up to date');
      continue;
    }
    stale++;
    if (check) {
      err.writeln('${o.path}: out of date, ${o.firstDifference}');
    } else {
      File(p.join(root, o.path))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(o.content);
      out.writeln('${o.path}: wrote');
    }
  }
  out.writeln(
    'mcgen buildgen: ${outputs.length} BUILD file(s), '
    '${check ? '$stale out of date' : '$stale written'}',
  );
  return check && stale > 0 ? 1 : 0;
}
