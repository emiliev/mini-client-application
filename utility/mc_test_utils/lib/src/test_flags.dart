import 'dart:async';

import 'package:mc_feature_flags/mc_feature_flags.dart';

/// The feature flags a feature test runs on (P-107, T-0056): a stub remote
/// snapshot, registered by `McTestContainer` as the root's
/// [FeatureFlagsReader].
///
/// The production root registers `FeatureFlags`, which fetches `/v1/flags`
/// at boot. A feature test serves only its own domains (the harness fails
/// on any unmatched request), so the container registers this stub instead:
/// no request, no storage, no session listener. A test sets a raw remote
/// value per key with [set] (the BDD step `the flag {key} is {value}`), and
/// every read decodes it with the flag's own codec, as `FeatureFlags` does
/// with a remote value: a key with no value, or a value of the wrong type,
/// is the flag's default.
final class McTestFlags implements FeatureFlagsReader {
  final Map<String, Object> _remote = {};
  final Map<String, String> _variants = {};
  final Set<String> _read = {};
  final List<_Watch> _watches = [];

  /// The keys a feature has read so far (`value` or `watch`), for tests
  /// that check a flag is consulted at all.
  Set<String> get readKeys => Set.unmodifiable(_read);

  /// Sets the remote value of [key] to [raw] (JSON-shaped: `bool`, `int`,
  /// `String`), or removes it when [raw] is null. Watchers see the change.
  void set(String key, Object? raw) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'A flag key is required');
    }
    if (raw == null) {
      _remote.remove(key);
    } else {
      _remote[key] = raw;
    }
    for (final watch in List.of(_watches)) {
      if (watch.key == key) {
        watch.emit();
      }
    }
  }

  /// Puts the subject in [variant] of the experiment with [key].
  void forceVariant(String key, String variant) => _variants[key] = variant;

  @override
  T value<T extends Object>(FeatureFlag<T> flag) {
    _read.add(flag.key);
    return _decode(flag);
  }

  T _decode<T extends Object>(FeatureFlag<T> flag) =>
      flag.codec.decode(_remote[flag.key]) ?? flag.defaultValue;

  @override
  Stream<T> watch<T extends Object>(FeatureFlag<T> flag) {
    _read.add(flag.key);
    late final _Watch watch;
    T? last;
    final controller = StreamController<T>(
      onCancel: () => _watches.remove(watch),
    );
    void emit() {
      final next = _decode(flag);
      if (next != last) {
        last = next;
        controller.add(next);
      }
    }

    watch = _Watch(flag.key, emit);
    _watches.add(watch);
    emit();
    return controller.stream;
  }

  /// The forced variant, else the experiment's first (its control).
  @override
  String variant(Experiment experiment) {
    final forced = _variants[experiment.key];
    if (forced != null && experiment.variants.any((v) => v.name == forced)) {
      return forced;
    }
    return experiment.variants.first.name;
  }

  /// Nothing to fetch: the snapshot is the test's.
  @override
  Future<void> refresh() async {}
}

final class _Watch {
  _Watch(this.key, this.emit);

  final String key;
  final void Function() emit;
}
