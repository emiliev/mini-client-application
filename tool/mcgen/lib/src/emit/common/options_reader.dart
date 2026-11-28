// Reads an archetype's `options` map (the schema leaves it open), naming the
// YAML path in every error. Shared by archetypes whose options are typed
// (T-0072; list_detail keeps its own private copy).

import 'package:yaml/yaml.dart';

/// Thrown for options an archetype cannot read; its lint reports them.
class OptionsError implements Exception {
  OptionsError(this.node, this.path, this.message);

  final YamlNode? node;
  final String path;
  final String message;
}

class OptionsReader {
  OptionsReader(this.node, this.path);

  final YamlNode? node;
  final String path;

  YamlMap? get _map => node is YamlMap ? node! as YamlMap : null;

  bool get isPresent => _map != null;

  Never fail(String key, String message) =>
      throw OptionsError(_map?.nodes[key] ?? node, '$path.$key', message);

  Object? _value(String key) => _map?[key];

  bool has(String key) => _map?.containsKey(key) ?? false;

  String str(String key, [String? fallback]) {
    final v = _value(key);
    if (v == null && fallback != null) return fallback;
    if (v is! String || v.isEmpty) fail(key, '"$key" must be a string');
    return v;
  }

  String? optStr(String key) {
    final v = _value(key);
    if (v == null) return null;
    if (v is! String) fail(key, '"$key" must be a string');
    return v;
  }

  int? optInt(String key) {
    final v = _value(key);
    if (v == null) return null;
    if (v is! int) fail(key, '"$key" must be an integer');
    return v;
  }

  int integer(String key, [int? fallback]) {
    final v = _value(key);
    if (v == null && fallback != null) return fallback;
    if (v is! int) fail(key, '"$key" must be an integer');
    return v;
  }

  bool boolean(String key) {
    final v = _value(key);
    if (v == null) return false;
    if (v is! bool) fail(key, '"$key" must be true or false');
    return v;
  }

  List<YamlNode> list(String key) {
    final n = _map?.nodes[key];
    if (n == null) return const [];
    if (n is! YamlList) fail(key, '"$key" must be a list');
    return n.nodes;
  }

  /// The items of list [key], each read by [read].
  List<T> items<T>(String key, T Function(OptionsReader r) read) => [
    for (final (i, n) in list(key).indexed)
      read(OptionsReader(n, '$path.$key[$i]')),
  ];

  List<String> strList(String key) => [
    for (final n in list(key)) '${n.value}',
  ];

  OptionsReader child(String key) {
    final n = _map?.nodes[key];
    if (n != null && n is! YamlMap) fail(key, '"$key" must be a map');
    return OptionsReader(n, '$path.$key');
  }

  Iterable<MapEntry<String, YamlNode>> get entries => [
    for (final e
        in _map?.nodes.entries ?? const <MapEntry<Object?, YamlNode>>[])
      MapEntry('${(e.key as YamlNode).value}', e.value),
  ];

  /// Rejects keys outside [keys].
  void only(List<String> keys) {
    for (final e
        in _map?.nodes.entries ?? const <MapEntry<Object?, YamlNode>>[]) {
      final k = '${(e.key as YamlNode).value}';
      if (!keys.contains(k)) {
        throw OptionsError(e.key as YamlNode, '$path.$k', 'unknown key "$k"');
      }
    }
  }

  Map<String, String> strMap(String key) {
    final c = child(key);
    return {for (final e in c.entries) e.key: '${e.value.value}'};
  }
}
