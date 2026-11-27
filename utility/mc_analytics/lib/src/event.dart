/// One tracked event: a snake_case [name] and typed [params].
///
/// Param values are `String`, `int`, `double` or `bool`; the facade checks
/// them (see [AnalyticsRules]), because Dart cannot spell that union as a
/// type.
class AnalyticsEvent {
  const AnalyticsEvent(this.name, {this.params = const <String, Object>{}});

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => 'AnalyticsEvent($name, $params)';
}

/// Why an event, screen or user property was rejected.
enum AnalyticsViolationKind {
  /// The name is not snake_case (`[a-z][a-z0-9]*(_[a-z0-9]+)*`), or is empty.
  badName,
  nameTooLong,

  /// The name starts with a prefix the kit keeps for itself.
  reservedName,
  tooManyParams,
  badParamKey,
  paramKeyTooLong,

  /// A param key the kit adds itself (`session_id`, `seq`, `screen_name`).
  reservedParamKey,

  /// A value that is not a `String`, `int`, `double` or `bool`.
  unsupportedValueType,

  /// A `double` that is NaN or infinite.
  nonFiniteNumber,
  stringTooLong,
}

/// One broken rule.
class AnalyticsViolation {
  const AnalyticsViolation(this.kind, this.message);

  final AnalyticsViolationKind kind;
  final String message;

  @override
  String toString() => message;
}

/// What the facade reports to monitoring when it drops an invalid event in
/// release mode (in debug mode it throws an [AssertionError] instead).
class AnalyticsValidationError implements Exception {
  const AnalyticsValidationError(this.what, this.violations);

  final String what;
  final List<AnalyticsViolation> violations;

  @override
  String toString() =>
      'AnalyticsValidationError: invalid $what dropped: '
      '${violations.join('; ')}';
}

/// The documented validation rules (plan 01 U06, T-0053-AC2).
///
/// - A name or param key is snake_case, 1 to [maxNameLength] characters.
/// - An event has at most [maxParams] params.
/// - A string value has at most [maxStringLength] characters (Unicode code
///   points). Numbers must be finite.
/// - A name starting with one of [reservedPrefixes] is for the kit (and, for
///   `ga_`, `firebase_` and `google_`, for a future vendor sink).
/// - [reservedParamKeys] are added by the kit and cannot be passed.
abstract final class AnalyticsRules {
  static const int maxNameLength = 40;
  static const int maxParams = 25;
  static const int maxStringLength = 100;

  /// The kit's own prefix; only the kit's events (`mc_session_start`,
  /// `mc_screen_view`) use it.
  static const String kitPrefix = 'mc_';
  static const List<String> reservedPrefixes = [
    kitPrefix,
    'ga_',
    'firebase_',
    'google_',
  ];
  static const List<String> reservedParamKeys = [
    'session_id',
    'seq',
    'screen_name',
  ];

  static final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

  /// Whether [name] is a valid name of 1 to [maxNameLength] snake_case
  /// characters (reserved prefixes are a separate rule).
  static bool isValidName(String name) =>
      name.length <= maxNameLength && _snakeCase.hasMatch(name);

  /// Every rule [name] breaks as the name of an event or user property.
  static List<AnalyticsViolation> validateName(
    String name, {
    bool allowReserved = false,
  }) {
    final out = <AnalyticsViolation>[];
    if (!_snakeCase.hasMatch(name)) {
      out.add(
        AnalyticsViolation(
          AnalyticsViolationKind.badName,
          'name "$name" is not snake_case',
        ),
      );
    }
    if (name.length > maxNameLength) {
      out.add(
        AnalyticsViolation(
          AnalyticsViolationKind.nameTooLong,
          'name "$name" is ${name.length} characters (max $maxNameLength)',
        ),
      );
    }
    if (!allowReserved) {
      for (final prefix in reservedPrefixes) {
        if (name.startsWith(prefix)) {
          out.add(
            AnalyticsViolation(
              AnalyticsViolationKind.reservedName,
              'name "$name" uses the reserved prefix "$prefix"',
            ),
          );
        }
      }
    }
    return out;
  }

  /// Every rule [value] breaks as a param or user property value.
  static List<AnalyticsViolation> validateValue(String where, Object value) {
    if (value is String) {
      final length = value.runes.length;
      return [
        if (length > maxStringLength)
          AnalyticsViolation(
            AnalyticsViolationKind.stringTooLong,
            '$where is $length characters (max $maxStringLength)',
          ),
      ];
    }
    if (value is double) {
      return [
        if (!value.isFinite)
          AnalyticsViolation(
            AnalyticsViolationKind.nonFiniteNumber,
            '$where is not a finite number',
          ),
      ];
    }
    if (value is int || value is bool) {
      return const [];
    }
    return [
      AnalyticsViolation(
        AnalyticsViolationKind.unsupportedValueType,
        '$where is a ${value.runtimeType}; only String, int, double and bool '
        'are allowed',
      ),
    ];
  }

  /// Every rule an event named [name] with [params] breaks. [allowReserved]
  /// is for the kit's own events.
  static List<AnalyticsViolation> validateEvent(
    String name,
    Map<String, Object> params, {
    bool allowReserved = false,
  }) {
    final out = [...validateName(name, allowReserved: allowReserved)];
    if (params.length > maxParams) {
      out.add(
        AnalyticsViolation(
          AnalyticsViolationKind.tooManyParams,
          '${params.length} params (max $maxParams)',
        ),
      );
    }
    for (final MapEntry(:key, :value) in params.entries) {
      if (!_snakeCase.hasMatch(key)) {
        out.add(
          AnalyticsViolation(
            AnalyticsViolationKind.badParamKey,
            'param key "$key" is not snake_case',
          ),
        );
      }
      if (key.length > maxNameLength) {
        out.add(
          AnalyticsViolation(
            AnalyticsViolationKind.paramKeyTooLong,
            'param key "$key" is ${key.length} characters '
            '(max $maxNameLength)',
          ),
        );
      }
      if (!allowReserved && reservedParamKeys.contains(key)) {
        out.add(
          AnalyticsViolation(
            AnalyticsViolationKind.reservedParamKey,
            'param key "$key" is added by the kit',
          ),
        );
      }
      out.addAll(validateValue('param "$key"', value));
    }
    return out;
  }
}
