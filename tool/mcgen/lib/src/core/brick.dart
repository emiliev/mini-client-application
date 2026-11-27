// Bricks in mason's format (`brick.yaml` plus a `__brick__/` tree), rendered
// with package:mustache_template, the engine mason itself uses (F-0065).
//
// mcgen passes fully precomputed variables, so templates stay logic-less:
// no lambdas, no partials, no hooks. That subset renders the same under
// `mason make`, so humans can still run a brick by hand.
//
// Rendering is strict: a template may use only the variables its brick.yaml
// declares, every declared variable must be given, and a missing value is an
// error rather than an empty string (mason renders leniently; a template that
// renders strictly renders the same leniently). Escaping is mustache's and
// mason's default: `{{x}}` HTML-escapes, so templates write raw values as
// `{{{x}}}`. A file whose rendered path is empty, or has an empty segment, is
// skipped: that is mason's conditional-file idiom (`{{#flag}}x.dart{{/flag}}`).

import 'dart:io';

import 'package:mustache_template/mustache_template.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class BrickError implements Exception {
  BrickError(this.message);

  final String message;

  @override
  String toString() => message;
}

class Brick {
  Brick._(this.name, this.vars, this._templates);

  /// Loads the brick in [dir] (`bricks/<name>`).
  factory Brick.load(String dir) {
    final yamlFile = File(p.join(dir, 'brick.yaml'));
    if (!yamlFile.existsSync()) {
      throw BrickError('no brick.yaml in ${p.basename(dir)}');
    }
    final y = loadYaml(yamlFile.readAsStringSync());
    if (y is! YamlMap || y['name'] is! String) {
      throw BrickError('${p.basename(dir)}/brick.yaml needs a name');
    }
    final name = y['name'] as String;
    if (name != p.basename(dir)) {
      throw BrickError(
        'brick "$name" must live in bricks/$name, not ${p.basename(dir)}',
      );
    }
    final varsNode = y['vars'];
    final vars = varsNode is YamlMap
        ? {for (final k in varsNode.keys) '$k'}
        : <String>{};
    final root = Directory(p.join(dir, '__brick__'));
    if (!root.existsSync()) {
      throw BrickError('brick "$name" has no __brick__ directory');
    }
    final templates = <String, String>{};
    for (final f
        in root
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()) {
      final rel = p.posix.joinAll(p.split(p.relative(f.path, from: root.path)));
      templates[rel] = f.readAsStringSync();
    }
    return Brick._(name, vars, templates);
  }

  final String name;

  /// Declared variable names.
  final Set<String> vars;

  /// Template path -> template text.
  final Map<String, String> _templates;

  /// Renders every file; returns module-relative path -> content, sorted.
  Map<String, String> render(Map<String, Object?> values) {
    final given = values.keys.toSet();
    final missing = vars.difference(given);
    final undeclared = given.difference(vars);
    if (missing.isNotEmpty || undeclared.isNotEmpty) {
      throw BrickError(
        'brick "$name": '
        '${missing.isEmpty ? '' : 'missing ${(missing.toList()..sort()).join(', ')}'}'
        '${missing.isNotEmpty && undeclared.isNotEmpty ? '; ' : ''}'
        '${undeclared.isEmpty ? '' : 'not declared in brick.yaml: ${(undeclared.toList()..sort()).join(', ')}'}',
      );
    }
    final out = <String, String>{};
    for (final path in (_templates.keys.toList()..sort())) {
      final target = _render(path, values, '$name:$path (path)');
      final segments = target.split('/');
      if (target.isEmpty || segments.any((s) => s.isEmpty)) continue;
      if (segments.any((s) => s == '..' || s == '.') ||
          target.startsWith('/')) {
        throw BrickError(
          'brick "$name": $path renders to an unsafe path "$target"',
        );
      }
      if (out.containsKey(target)) {
        throw BrickError('brick "$name": two templates render to $target');
      }
      out[target] = _render(_templates[path]!, values, '$name:$path');
    }
    return out;
  }

  String _render(String template, Map<String, Object?> values, String where) {
    try {
      // mustache_template's default escaping, as mason renders: templates
      // write raw values as `{{{name}}}`.
      return Template(template, name: where).renderString(values);
    } on TemplateException catch (e) {
      throw BrickError('$where: ${e.message}');
    }
  }
}

/// The bricks directory, loading each brick once.
class BrickSet {
  BrickSet(this.dir);

  final String dir;
  final _cache = <String, Brick>{};

  Brick operator [](String name) =>
      _cache.putIfAbsent(name, () => Brick.load(p.join(dir, name)));
}
