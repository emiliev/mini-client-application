/// Why a field is invalid. Features map a code to a localised message; the
/// kit never produces text.
enum ValidationCode {
  /// A required value is missing (null, blank text or an empty collection).
  required,

  /// Text is shorter than [FieldError.min].
  tooShort,

  /// Text is longer than [FieldError.max].
  tooLong,

  /// Text does not match the expected pattern.
  patternMismatch,

  /// A number is below [FieldError.min].
  belowMin,

  /// A number is above [FieldError.max].
  aboveMax,

  /// A value differs from the field it must equal (confirm password).
  mismatch,

  /// A feature-specific rule failed.
  invalid,
}

/// A failed rule: a typed [code] plus the limits a message may quote.
final class FieldError {
  const FieldError(this.code, {this.min, this.max});

  final ValidationCode code;

  /// The lower limit that was broken, when the rule has one.
  final num? min;

  /// The upper limit that was broken, when the rule has one.
  final num? max;

  @override
  bool operator ==(Object other) =>
      other is FieldError &&
      other.code == code &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(code, min, max);

  @override
  String toString() => 'FieldError($code, min: $min, max: $max)';
}
