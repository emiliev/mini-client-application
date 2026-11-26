import 'package:mc_forms/src/field_error.dart';
import 'package:mc_forms/src/form_values.dart';

/// Checks one field's value. Returns null when valid.
typedef Validator<T> = FieldError? Function(T? value);

/// Checks one field's value against the other fields (confirm equals).
typedef CrossValidator<T> = FieldError? Function(T? value, FormValues values);

/// What a controller needs to know about a field, without its type.
abstract interface class FieldSpec {
  String get name;
  Object? get initial;

  /// The first error of the field's rules, or null.
  FieldError? check(Object? value, FormValues values);
}

/// A named, typed field with its rules. [validators] run first, then
/// [crossValidators]; the first error wins.
final class FieldDef<T> implements FieldSpec {
  const FieldDef(
    this.name, {
    this.initial,
    this.validators = const [],
    this.crossValidators = const [],
  });

  @override
  final String name;

  @override
  final T? initial;

  final List<Validator<T>> validators;
  final List<CrossValidator<T>> crossValidators;

  @override
  FieldError? check(Object? value, FormValues values) {
    final typed = value as T?;
    for (final v in validators) {
      final error = v(typed);
      if (error != null) {
        return error;
      }
    }
    for (final v in crossValidators) {
      final error = v(typed, values);
      if (error != null) {
        return error;
      }
    }
    return null;
  }
}
