import 'package:mc_feature_flags/src/bucketing.dart' show maxVariantWeight;

/// How a flag's value moves to and from JSON. [decode] returns null for a
/// value of the wrong type (the evaluation then falls to the next source), so
/// a flag's `T` is never nullable.
abstract interface class FlagCodec<T extends Object> {
  /// The value, or null when [raw] is not a valid `T`.
  T? decode(Object? raw);

  /// The JSON form of [value] (what overrides persist).
  Object encode(T value);
}

/// A JSON `true` or `false`.
final class BoolFlagCodec implements FlagCodec<bool> {
  const BoolFlagCodec();

  @override
  bool? decode(Object? raw) => raw is bool ? raw : null;

  @override
  Object encode(bool value) => value;
}

/// A JSON integer. A number with a fraction (`5.0`) is not an int.
final class IntFlagCodec implements FlagCodec<int> {
  const IntFlagCodec();

  @override
  int? decode(Object? raw) => raw is int ? raw : null;

  @override
  Object encode(int value) => value;
}

/// A JSON string.
final class StringFlagCodec implements FlagCodec<String> {
  const StringFlagCodec();

  @override
  String? decode(Object? raw) => raw is String ? raw : null;

  @override
  Object encode(String value) => value;
}

/// An enum, as the `name` of one of [values] (`MyEnum.values`). A name that
/// no value has decodes to null.
final class EnumFlagCodec<E extends Enum> implements FlagCodec<E> {
  const EnumFlagCodec(this.values);

  final List<E> values;

  @override
  E? decode(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  @override
  Object encode(E value) => value.name;
}

/// A feature flag: its key, the value it has when nothing else says, and how
/// to read it from JSON. A feature declares its flags as `const` values in
/// its own package; the kit holds none.
///
/// ```dart
/// const promoBanner = FeatureFlag<bool>(
///   key: 'store.promo_banner',
///   defaultValue: false,
///   description: 'Shows the promotion banner on the store home.',
///   codec: BoolFlagCodec(),
/// );
/// ```
final class FeatureFlag<T extends Object> {
  const FeatureFlag({
    required this.key,
    required this.defaultValue,
    required this.description,
    required this.codec,
  });

  /// Unique across the app. Registering or using a second, different flag
  /// with the same key throws.
  final String key;
  final T defaultValue;
  final String description;
  final FlagCodec<T> codec;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureFlag<T> &&
          other.key == key &&
          other.defaultValue == defaultValue &&
          other.description == description &&
          other.codec.runtimeType == codec.runtimeType);

  @override
  int get hashCode => Object.hash(key, defaultValue, description);

  @override
  String toString() => 'FeatureFlag<$T>($key)';
}

/// One variant of an [Experiment] and its default weight.
final class ExperimentVariant {
  const ExperimentVariant(this.name, this.weight);

  final String name;

  /// A relative, non-negative integer. A zero weight never gets a subject.
  final int weight;

  @override
  bool operator ==(Object other) =>
      other is ExperimentVariant &&
      other.name == name &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(name, weight);

  @override
  String toString() => '$name:$weight';
}

/// An experiment: a key and its variants with default weights. Remote config
/// can replace the weights; a local override can force a variant. The first
/// variant is the control: it is the answer when no weight is positive.
final class Experiment {
  const Experiment({
    required this.key,
    required this.variants,
    this.description = '',
  });

  final String key;
  final List<ExperimentVariant> variants;
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Experiment &&
          other.key == key &&
          other.description == description &&
          _sameVariants(other.variants, variants));

  @override
  int get hashCode => Object.hash(key, description, variants.length);

  @override
  String toString() => 'Experiment($key)';
}

bool _sameVariants(List<ExperimentVariant> a, List<ExperimentVariant> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// Thrown when a second, different flag or experiment uses a key that is
/// already registered (or registering the same key twice).
final class DuplicateFlagKeyError extends Error {
  DuplicateFlagKeyError(this.key, this.kind);

  final String key;

  /// `flag` or `experiment`.
  final String kind;

  @override
  String toString() =>
      'DuplicateFlagKeyError: the $kind key "$key" is '
      'already registered';
}

/// The flags and experiments known so far. Keys are unique. A flag is
/// registered explicitly with [registerFlag], or implicitly the first time it
/// is evaluated; the explicit call of a key that is already known throws, the
/// implicit one throws only when the flag differs from the one registered.
final class FeatureFlagRegistry {
  final Map<String, FeatureFlag<Object>> _flags = {};
  final Map<String, Experiment> _experiments = {};

  /// The registered flags, in registration order.
  List<FeatureFlag<Object>> get flags => List.unmodifiable(_flags.values);

  /// The registered experiments, in registration order.
  List<Experiment> get experiments => List.unmodifiable(_experiments.values);

  /// Registers [flag]. Throws [DuplicateFlagKeyError] when its key is known.
  void registerFlag(FeatureFlag<Object> flag) {
    _checkFlag(flag);
    if (_flags.containsKey(flag.key)) {
      throw DuplicateFlagKeyError(flag.key, 'flag');
    }
    _flags[flag.key] = flag;
  }

  /// Registers [experiment]. Throws [DuplicateFlagKeyError] when its key is
  /// known.
  void registerExperiment(Experiment experiment) {
    _checkExperiment(experiment);
    if (_experiments.containsKey(experiment.key)) {
      throw DuplicateFlagKeyError(experiment.key, 'experiment');
    }
    _experiments[experiment.key] = experiment;
  }

  /// Registers [flag] unless the same flag is already known. Throws
  /// [DuplicateFlagKeyError] when the key belongs to a different flag.
  void bindFlag(FeatureFlag<Object> flag) {
    final known = _flags[flag.key];
    if (known == null) {
      registerFlag(flag);
    } else if (!identical(known, flag) && known != flag) {
      throw DuplicateFlagKeyError(flag.key, 'flag');
    }
  }

  /// [bindFlag] for an experiment.
  void bindExperiment(Experiment experiment) {
    final known = _experiments[experiment.key];
    if (known == null) {
      registerExperiment(experiment);
    } else if (!identical(known, experiment) && known != experiment) {
      throw DuplicateFlagKeyError(experiment.key, 'experiment');
    }
  }

  static void _checkFlag(FeatureFlag<Object> flag) {
    if (flag.key.trim().isEmpty) {
      throw ArgumentError.value(flag.key, 'key', 'A flag key is required');
    }
  }

  static void _checkExperiment(Experiment experiment) {
    if (experiment.key.trim().isEmpty) {
      throw ArgumentError.value(
        experiment.key,
        'key',
        'An experiment key is required',
      );
    }
    if (experiment.variants.isEmpty) {
      throw ArgumentError.value(
        experiment.key,
        'variants',
        'An experiment needs at least one variant',
      );
    }
    final names = <String>{};
    for (final variant in experiment.variants) {
      if (variant.weight < 0 || variant.weight > maxVariantWeight) {
        throw ArgumentError.value(
          variant.weight,
          'weight',
          'The weight of ${experiment.key}:${variant.name} is not between 0 '
              'and $maxVariantWeight',
        );
      }
      if (!names.add(variant.name)) {
        throw ArgumentError.value(
          variant.name,
          'variants',
          'Variant names of ${experiment.key} must be unique',
        );
      }
    }
  }
}
