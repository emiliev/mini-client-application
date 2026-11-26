/// A read-only snapshot of every field's value, by field name.
final class FormValues {
  FormValues(Map<String, Object?> values)
    : _values = Map<String, Object?>.unmodifiable(values);

  final Map<String, Object?> _values;

  /// The value of [name], or null when unset. Throws an [ArgumentError] for
  /// an unknown field, and a [TypeError] when the value is not a [T].
  T? get<T>(String name) {
    if (!_values.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'unknown field');
    }
    return _values[name] as T?;
  }

  Map<String, Object?> toMap() => _values;
}
