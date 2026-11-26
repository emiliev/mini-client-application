import 'package:mc_forms/src/field_error.dart';

/// One field's value and status. Immutable.
///
/// [error] is always current for [value]; whether to show it is the UI's
/// call: show [visibleError], which is empty until the field is touched.
final class FieldState<T> {
  const FieldState({
    required this.value,
    required this.initial,
    this.error,
    this.touched = false,
  });

  final T? value;
  final T? initial;
  final FieldError? error;
  final bool touched;

  /// The value differs from the initial one.
  bool get dirty => value != initial;

  bool get isValid => error == null;

  /// The error to show: null until the field is touched.
  FieldError? get visibleError => touched ? error : null;

  FieldState<T> withValue(T? value, FieldError? error) => FieldState<T>(
    value: value,
    initial: initial,
    error: error,
    touched: touched,
  );

  FieldState<T> withError(FieldError? error) => FieldState<T>(
    value: value,
    initial: initial,
    error: error,
    touched: touched,
  );

  FieldState<T> touch() => touched
      ? this
      : FieldState<T>(
          value: value,
          initial: initial,
          error: error,
          touched: true,
        );

  @override
  bool operator ==(Object other) =>
      other is FieldState<T> &&
      other.value == value &&
      other.initial == initial &&
      other.error == error &&
      other.touched == touched;

  @override
  int get hashCode => Object.hash(value, initial, error, touched);

  @override
  String toString() =>
      'FieldState(value: $value, initial: $initial, error: $error, '
      'touched: $touched)';
}
