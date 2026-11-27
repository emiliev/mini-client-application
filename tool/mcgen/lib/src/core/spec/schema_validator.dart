// A JSON Schema (2020-12) validator for the keyword subset mcgen-1.json uses,
// run over YAML nodes so every error keeps its line and column.
//
// Any keyword outside the subset is rejected when the schema loads, so the
// committed schema can never rely on something this validator silently
// ignores.

import 'dart:convert';
import 'dart:io';

import 'package:mcgen/src/core/diagnostics.dart';
import 'package:yaml/yaml.dart';

const _supported = {
  r'$schema',
  r'$id',
  r'$defs',
  r'$ref',
  'title',
  'description',
  'type',
  'properties',
  'required',
  'additionalProperties',
  'items',
  'enum',
  'const',
  'pattern',
  'minLength',
  'minItems',
  'minimum',
  'uniqueItems',
};

/// The committed schema, loaded once.
class SpecSchema {
  SpecSchema._(this._root);

  /// Parses [source] (the schema JSON) and checks it uses only the subset.
  factory SpecSchema.parse(String source) {
    final root = jsonDecode(source);
    if (root is! Map<String, Object?>) {
      throw const FormatException('schema root is not an object');
    }
    _checkKeywords(root, r'#');
    return SpecSchema._(root);
  }

  /// Loads `schema/mcgen-1.json` from [path].
  factory SpecSchema.load(String path) =>
      SpecSchema.parse(File(path).readAsStringSync());

  final Map<String, Object?> _root;

  static void _checkKeywords(Map<String, Object?> s, String at) {
    for (final k in s.keys) {
      if (!_supported.contains(k)) {
        throw FormatException('unsupported schema keyword "$k" at $at');
      }
    }
    final props = s['properties'];
    if (props is Map<String, Object?>) {
      props.forEach((k, v) {
        if (v is Map<String, Object?>) _checkKeywords(v, '$at/properties/$k');
      });
    }
    final defs = s[r'$defs'];
    if (defs is Map<String, Object?>) {
      defs.forEach((k, v) {
        if (v is Map<String, Object?>) _checkKeywords(v, '$at/\$defs/$k');
      });
    }
    for (final k in ['items', 'additionalProperties']) {
      final v = s[k];
      if (v is Map<String, Object?>) _checkKeywords(v, '$at/$k');
    }
  }

  /// Validates [doc]; diagnostics name [file] and carry YAML paths.
  List<Diagnostic> validate(YamlNode doc, String file) {
    final out = <Diagnostic>[];
    _validate(_root, doc, '', file, out);
    out.sort();
    return out;
  }

  Map<String, Object?> _deref(Map<String, Object?> s) {
    var cur = s;
    var guard = 0;
    while (cur[r'$ref'] is String) {
      final ref = cur[r'$ref']! as String;
      if (!ref.startsWith(r'#/$defs/')) {
        throw FormatException('only local \$defs refs are supported: $ref');
      }
      final name = ref.substring(r'#/$defs/'.length);
      final defs = _root[r'$defs'];
      final target = defs is Map<String, Object?> ? defs[name] : null;
      if (target is! Map<String, Object?>) {
        throw FormatException('unresolved \$ref: $ref');
      }
      cur = target;
      if (++guard > 32) throw FormatException('\$ref cycle at $ref');
    }
    return cur;
  }

  void _validate(
    Map<String, Object?> schema,
    YamlNode node,
    String path,
    String file,
    List<Diagnostic> out,
  ) {
    final s = _deref(schema);
    void err(String message, [YamlNode? at]) => out.add(
      Diagnostic.at(
        at ?? node,
        code: 'schema',
        message: message,
        file: file,
        yamlPath: path.isEmpty ? r'$' : path,
      ),
    );

    if (s.containsKey('const')) {
      final c = s['const'];
      if (_plain(node) != c) {
        err('must be ${jsonEncode(c)}');
        return;
      }
    }
    if (s['enum'] is List) {
      final values = s['enum']! as List;
      if (!values.contains(_plain(node))) {
        err('must be one of ${values.map(jsonEncode).join(', ')}');
        return;
      }
    }
    final type = s['type'];
    if (type != null) {
      final types = type is List ? type.cast<String>() : [type as String];
      if (!types.any((t) => _isType(node, t))) {
        err('expected ${types.join(' or ')}, got ${_typeOf(node)}');
        return;
      }
    }
    if (node is YamlScalar && node.value is String) {
      final v = node.value as String;
      final minLength = s['minLength'];
      if (minLength is int && v.length < minLength) {
        err('must have at least $minLength character(s)');
      }
      final pattern = s['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(v)) {
        err('"$v" does not match /$pattern/');
      }
    }
    if (node is YamlScalar && node.value is num) {
      final minimum = s['minimum'];
      if (minimum is num && (node.value as num) < minimum) {
        err('must be >= $minimum');
      }
    }
    if (node is YamlList) {
      final minItems = s['minItems'];
      if (minItems is int && node.nodes.length < minItems) {
        err('must have at least $minItems item(s)');
      }
      if (s['uniqueItems'] == true) {
        final seen = <String>{};
        for (var i = 0; i < node.nodes.length; i++) {
          final key = jsonEncode(_plain(node.nodes[i]));
          if (!seen.add(key)) {
            out.add(
              Diagnostic.at(
                node.nodes[i],
                code: 'schema',
                message: 'duplicate item $key',
                file: file,
                yamlPath: '$path[$i]',
              ),
            );
          }
        }
      }
      final items = s['items'];
      if (items is Map<String, Object?>) {
        for (var i = 0; i < node.nodes.length; i++) {
          _validate(items, node.nodes[i], '$path[$i]', file, out);
        }
      }
    }
    if (node is YamlMap) {
      final props = (s['properties'] as Map<String, Object?>?) ?? const {};
      final required = (s['required'] as List?)?.cast<String>() ?? const [];
      final keys = <String, YamlNode>{};
      for (final e in node.nodes.entries) {
        final k = (e.key as YamlNode).value;
        if (k is! String) {
          err('keys must be strings', e.key as YamlNode);
          continue;
        }
        keys[k] = e.key as YamlNode;
      }
      for (final r in required) {
        if (!keys.containsKey(r)) err('missing required key "$r"');
      }
      final additional = s['additionalProperties'];
      for (final e in node.nodes.entries) {
        final k = (e.key as YamlNode).value;
        if (k is! String) continue;
        final child = e.value;
        final childPath = path.isEmpty ? k : '$path.$k';
        final ps = props[k];
        if (ps is Map<String, Object?>) {
          _validate(ps, child, childPath, file, out);
        } else if (additional == false) {
          out.add(
            Diagnostic.at(
              e.key as YamlNode,
              code: 'schema',
              message: 'unknown key "$k"',
              file: file,
              yamlPath: childPath,
            ),
          );
        } else if (additional is Map<String, Object?>) {
          _validate(additional, child, childPath, file, out);
        }
      }
    }
  }

  static bool _isType(YamlNode n, String t) => switch (t) {
    'object' => n is YamlMap,
    'array' => n is YamlList,
    'string' => n is YamlScalar && n.value is String,
    'integer' => n is YamlScalar && n.value is int,
    'number' => n is YamlScalar && n.value is num,
    'boolean' => n is YamlScalar && n.value is bool,
    'null' => n is YamlScalar && n.value == null,
    _ => throw FormatException('unknown schema type "$t"'),
  };

  static String _typeOf(YamlNode n) {
    if (n is YamlMap) return 'object';
    if (n is YamlList) return 'array';
    final v = (n as YamlScalar).value;
    return switch (v) {
      null => 'null',
      String() => 'string',
      int() => 'integer',
      double() => 'number',
      bool() => 'boolean',
      _ => v.runtimeType.toString(),
    };
  }
}

/// A YAML node as plain JSON-like Dart values (maps keep insertion order).
Object? _plain(YamlNode n) {
  if (n is YamlMap) {
    return {
      for (final e in n.nodes.entries)
        '${(e.key as YamlNode).value}': _plain(e.value),
    };
  }
  if (n is YamlList) return [for (final c in n.nodes) _plain(c)];
  return (n as YamlScalar).value;
}

/// [n] as plain values (exposed for the spec hash and archetype options).
Object? yamlToPlain(YamlNode n) => _plain(n);
