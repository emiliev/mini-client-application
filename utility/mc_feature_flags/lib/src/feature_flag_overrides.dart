import 'package:mc_feature_flags/src/feature_flag.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Why an override call did nothing (or was not saved).
enum FlagOverrideFailureReason {
  /// The environment is release-like: overrides are not accepted.
  releaseEnvironment,

  /// The variant is not one the experiment declares.
  unknownVariant,

  /// The change is applied in memory but could not be saved.
  storage,
}

/// An override call that was rejected or not saved.
final class FlagOverrideFailure implements Exception {
  const FlagOverrideFailure(this.reason, this.message);

  final FlagOverrideFailureReason reason;
  final String message;

  @override
  String toString() => 'FlagOverrideFailure(${reason.name}): $message';
}

/// Local overrides for development and tests: they win over every other
/// source, are saved on the device, and are accepted **only** when the app's
/// `env` is not release-like (anything but `dev`, `e2e`, `perf` and `test`).
/// In a release-like environment every call is rejected with
/// [FlagOverrideFailureReason.releaseEnvironment] and nothing already saved is
/// read.
///
/// A call changes the in-memory state at once and returns when the change is
/// saved. A save failure is returned as a value; the change stays in memory.
abstract interface class FeatureFlagOverrides {
  /// Whether overrides are accepted (the environment is not release-like).
  bool get isEnabled;

  /// Forces [flag] to [value].
  Future<Result<void, FlagOverrideFailure>> set<T extends Object>(
    FeatureFlag<T> flag,
    T value,
  );

  /// Removes the override of [flag]; a no-op when it has none.
  Future<Result<void, FlagOverrideFailure>> clear<T extends Object>(
    FeatureFlag<T> flag,
  );

  /// Forces [experiment] to the variant named [variant].
  Future<Result<void, FlagOverrideFailure>> forceVariant(
    Experiment experiment,
    String variant,
  );

  /// Removes the forced variant of [experiment]; a no-op when it has none.
  Future<Result<void, FlagOverrideFailure>> clearVariant(Experiment experiment);

  /// Removes every flag override and every forced variant.
  Future<Result<void, FlagOverrideFailure>> clearAll();
}

/// The environments in which overrides are accepted: the ones the app's
/// `config/<env>.json` files name for development, end-to-end and performance
/// runs, and `test`. Everything else (`release`, `prod`, `staging`, a typo) is
/// release-like, so an unknown name fails closed.
const Set<String> overridableEnvs = {'dev', 'e2e', 'perf', 'test'};

/// Whether [env] is release-like, so overrides are off.
bool isReleaseLikeEnv(String env) => !overridableEnvs.contains(env);
