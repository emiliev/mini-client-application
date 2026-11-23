import 'dart:convert';

/// Encodes [value] as JSON with every map's keys sorted, so equal data gives
/// byte-identical output (plan 01 §5 "Determinism").
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sorted(value[k])};
  }
  if (value is Iterable) return [for (final v in value) _sorted(v)];
  return value;
}
