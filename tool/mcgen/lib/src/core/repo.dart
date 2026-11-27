// The tree mcgen works on: the first-party packages that exist and the specs.

import 'dart:io';

import 'package:mcgen/src/core/spec/spec.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A first-party package: from a `pubspec.yaml` or a spec.
class RepoPackage {
  const RepoPackage(this.name, this.dir, this.tier);

  final String name;

  /// Root-relative posix directory.
  final String dir;
  final Tier tier;
}

const _skipDirs = {'build', 'ios', 'android', 'node_modules', 'Pods'};

class RepoIndex {
  RepoIndex._(this.root, this.packages, this.specFiles);

  /// Scans `app/`, `feature/` and `utility/` under [root] for `pubspec.yaml`
  /// and `mcgen.yaml`, skipping hidden, build and platform directories.
  factory RepoIndex.scan(String root) {
    final packages = <RepoPackage>[];
    final specs = <String>[];
    for (final tier in Tier.values) {
      final top = Directory(p.join(root, tier.name));
      if (!top.existsSync()) continue;
      _walk(top, (f) {
        final rel = p.posix.joinAll(p.split(p.relative(f.path, from: root)));
        final base = p.posix.basename(rel);
        if (base == 'mcgen.yaml') specs.add(rel);
        if (base == 'pubspec.yaml') {
          try {
            final y = loadYaml(f.readAsStringSync());
            if (y is YamlMap && y['name'] is String) {
              packages.add(
                RepoPackage(y['name'] as String, p.posix.dirname(rel), tier),
              );
            }
          } on YamlException {
            // An unparseable pubspec is not a package mcgen can reason about.
          }
        }
      });
    }
    packages.sort((a, b) => a.dir.compareTo(b.dir));
    specs.sort();
    return RepoIndex._(root, packages, specs);
  }

  static void _walk(Directory d, void Function(File) visit) {
    final entries = d.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final e in entries) {
      final name = p.basename(e.path);
      if (name.startsWith('.') || name.startsWith('bazel-')) continue;
      if (e is Directory) {
        if (_skipDirs.contains(name)) continue;
        _walk(e, visit);
      } else if (e is File) {
        visit(e);
      }
    }
  }

  final String root;
  final List<RepoPackage> packages;

  /// Root-relative spec paths, sorted.
  final List<String> specFiles;

  /// Packages named [name] (more than one is a collision).
  List<RepoPackage> named(String name) => [
    for (final pkg in packages)
      if (pkg.name == name) pkg,
  ];
}

/// The repository root above [from]: the nearest directory with a `.git`
/// entry (a directory, or a file in a worktree).
String? findRepoRoot(String from) {
  var dir = p.absolute(from);
  while (true) {
    if (FileSystemEntity.typeSync(p.join(dir, '.git')) !=
        FileSystemEntityType.notFound) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}
