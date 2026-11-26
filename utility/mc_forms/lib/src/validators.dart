import 'package:characters/characters.dart';
import 'package:mc_forms/src/field_error.dart';
import 'package:mc_forms/src/field_spec.dart';
import 'package:mc_forms/src/form_values.dart';

/// Validator rules. Each is a pure function. Except [required] and
/// [requiredWhen], an empty value (null or "") passes, so a rule composes
/// with [required] and an optional field stays optional.
abstract final class Validators {
  /// Fails with [ValidationCode.required] for null, blank text, or an empty
  /// collection.
  static Validator<T> required<T>() => (value) {
    final empty =
        value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is Iterable<Object?> && value.isEmpty) ||
        (value is Map<Object?, Object?> && value.isEmpty);
    return empty ? const FieldError(ValidationCode.required) : null;
  };

  /// Text of fewer than [min] characters (user-perceived: an emoji or an
  /// accented letter counts once, as `TextField.maxLength` counts) fails with
  /// [ValidationCode.tooShort].
  static Validator<String> minLength(int min) =>
      (value) =>
          value == null || value.isEmpty || value.characters.length >= min
          ? null
          : FieldError(ValidationCode.tooShort, min: min);

  /// Text of more than [max] characters fails with
  /// [ValidationCode.tooLong].
  static Validator<String> maxLength(int max) =>
      (value) => value == null || value.characters.length <= max
      ? null
      : FieldError(ValidationCode.tooLong, max: max);

  /// Text that does not match [regex] fails with [code] (default
  /// [ValidationCode.patternMismatch]). The whole text must match.
  static Validator<String> pattern(
    RegExp regex, {
    ValidationCode code = ValidationCode.patternMismatch,
  }) {
    // Anchored with look-arounds, not `^` and `$`, which a multiLine flag
    // would turn into line anchors. The group makes alternation (`a|ab`) and
    // lazy quantifiers (`\d+?`) match the whole text.
    final anchored = RegExp(
      r'(?<![\s\S])(?:' + regex.pattern + r')(?![\s\S])',
      multiLine: regex.isMultiLine,
      caseSensitive: regex.isCaseSensitive,
      unicode: regex.isUnicode,
      dotAll: regex.isDotAll,
    );
    return (value) {
      if (value == null || value.isEmpty) {
        return null;
      }
      return anchored.hasMatch(value) ? null : FieldError(code);
    };
  }

  /// A number outside `[min, max]` fails with [ValidationCode.belowMin] or
  /// [ValidationCode.aboveMax]. Both limits are inclusive. A null value
  /// passes.
  static Validator<T> range<T extends num>({T? min, T? max}) {
    if (min != null && max != null && min > max) {
      throw ArgumentError('min ($min) is above max ($max)');
    }
    return (value) {
      if (value == null) {
        return null;
      }
      if (min != null && value < min) {
        return FieldError(ValidationCode.belowMin, min: min, max: max);
      }
      if (max != null && value > max) {
        return FieldError(ValidationCode.aboveMax, min: min, max: max);
      }
      return null;
    };
  }

  /// Runs [rules] in order and returns the first error.
  static Validator<T> compose<T>(List<Validator<T>> rules) {
    final copy = List<Validator<T>>.of(rules);
    return (value) {
      for (final rule in copy) {
        final error = rule(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }

  /// Fails with [ValidationCode.mismatch] unless the value equals the value
  /// of field [other] (a confirm field).
  static CrossValidator<T> matches<T>(String other) =>
      (value, values) => value == values.get<Object>(other)
      ? null
      : const FieldError(ValidationCode.mismatch);

  /// Fails with [ValidationCode.required] when [condition] holds for the
  /// form and the value is missing.
  static CrossValidator<T> requiredWhen<T>(
    bool Function(FormValues values) condition,
  ) =>
      (value, values) =>
          condition(values) ? Validators.required<T>()(value) : null;
}
