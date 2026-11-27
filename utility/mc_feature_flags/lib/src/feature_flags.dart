import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_feature_flags/src/bucketing.dart';
import 'package:mc_feature_flags/src/feature_flag.dart';
import 'package:mc_feature_flags/src/feature_flag_overrides.dart';
import 'package:mc_feature_flags/src/remote_snapshot.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

/// The read side: what features see.
abstract interface class FeatureFlagsReader {
  /// The value of [flag] now, from the first source that has one (see
  /// [FeatureFlags]). Synchronous and never throws on bad data.
  T value<T extends Object>(FeatureFlag<T> flag);

  /// The value of [flag] now, then each later change. Equal values are not
  /// repeated. A single-subscription stream.
  Stream<T> watch<T extends Object>(FeatureFlag<T> flag);

  /// The variant of [experiment] the current subject (the signed-in user, or
  /// else this install) is in.
  String variant(Experiment experiment);

  /// Fetches the flags now (joining a fetch of this session that is already
  /// running). Never throws; a failure keeps the current values.
  Future<void> refresh();
}

/// Where the state lives in the [FileStore].
const String flagsCacheKey = 'feature_flags.cache';
const String flagsOverridesKey = 'feature_flags.overrides';
const String flagsInstallIdKey = 'feature_flags.install_id';

/// Typed feature flags and experiments.
///
/// ## Evaluation order (per flag)
/// 1. **Local override**, only when the `env` is not release-like
///    ([isReleaseLikeEnv]); overrides are saved in the [FileStore].
/// 2. **The remote value of the last successful fetch for the current session
///    epoch.**
/// 3. **The last-known-good remote value**: the cached body of the last
///    successful fetch **for the same user**, used only while no fetch has
///    succeeded yet in this epoch (a cold start, or a failing backend).
/// 4. **The flag's `defaultValue`.**
///
/// A source with no value for the key is skipped. A source with a value of the
/// wrong type is skipped too and reported once to [Monitoring]. Because a
/// successful fetch ends source 3, a key the server omits or sends with the
/// wrong type is the default, never an older value. Unknown remote keys are
/// ignored; a JSON `null` counts as no value.
///
/// Experiments follow the same order: a forced variant, then the remote
/// weights, then the last-known-good weights, then the declared weights.
///
/// ## The session epoch
/// The flags a user sees are fetched with that user's bearer (the shared
/// `Dio` adds it). A fetch remembers the epoch it started in; a result that
/// arrives after the epoch changed is dropped, before anything is applied or
/// written. The epoch is checked on every call as well as on `authState`, so a
/// change is never missed while waiting for the stream. A sign-in as the
/// **same** user starts a new epoch but sends no `authState` event, so its
/// refetch starts at the next read (`value`, `variant`, `refresh`); the old
/// values stay in use meanwhile as last-known-good.
///
/// [refresh] joins a fetch of the current epoch that is already running, so
/// it may answer with a request that started before the call.
///
/// ## Boot
/// [open] reads the saved state only when its files exist, and [start] begins
/// the fetch without waiting for it, so boot never waits on the network.
final class FeatureFlags implements FeatureFlagsReader, FeatureFlagOverrides {
  FeatureFlags._({
    required Dio dio,
    required SessionReader session,
    required FileStore store,
    required String env,
    required Monitoring? monitoring,
    required String Function() newInstallId,
  }) : _dio = dio,
       _session = session,
       _store = store,
       _env = env,
       _monitoring = monitoring,
       _newInstallId = newInstallId,
       _seenEpoch = session.epoch,
       _seenUserId = session.userId;

  /// Builds the flags on [store], reading what was saved there. [env] is
  /// `AppConfig.env`. Reading is real file I/O, so a file that does not exist
  /// is not read (a first launch costs no I/O, as in `SessionDIInitializer`).
  /// Call [start] to fetch.
  static Future<FeatureFlags> open({
    required Dio dio,
    required SessionReader session,
    required FileStore store,
    required String env,
    Monitoring? monitoring,
    String Function()? newInstallId,
  }) async {
    final flags = FeatureFlags._(
      dio: dio,
      session: session,
      store: store,
      env: env,
      monitoring: monitoring,
      newInstallId: newInstallId ?? _randomInstallId,
    );
    await flags._restore();
    flags._listen();
    return flags;
  }

  final Dio _dio;
  final SessionReader _session;
  final FileStore _store;
  final String _env;
  final Monitoring? _monitoring;
  final String Function() _newInstallId;

  /// The flags and experiments seen so far.
  final FeatureFlagRegistry registry = FeatureFlagRegistry();

  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  final Set<String> _reported = {};
  final Map<String, Object> _overrideFlags = {};
  final Map<String, String> _forcedVariants = {};

  StreamSubscription<AuthStatus>? _authSubscription;
  int _seenEpoch;
  String? _seenUserId;
  RemoteSnapshot? _remote;
  RemoteSnapshot? _lastKnownGood;
  String? _installId;
  ({int epoch, Future<void> future})? _inFlight;
  bool _disposed = false;

  bool get _overridesAllowed => !isReleaseLikeEnv(_env);

  // --- opening -----------------------------------------------------------

  Future<void> _restore() async {
    if (_overridesAllowed && _exists(flagsOverridesKey)) {
      final read = await _store.read(flagsOverridesKey);
      _loadOverrides(read.getOrNull());
    }
    if (_exists(flagsCacheKey)) {
      final read = await _store.read(flagsCacheKey);
      _lastKnownGood = RemoteSnapshot.fromCache(
        read.getOrNull(),
        forUser: _session.userId,
      );
    }
    if (_exists(flagsInstallIdKey)) {
      final read = await _store.read(flagsInstallIdKey);
      final id = read.getOrNull();
      if (id is String && id.isNotEmpty) {
        _installId = id;
      }
    }
  }

  bool _exists(String key) {
    try {
      return _store.existsSync(key);
    } on Object {
      // Cannot tell: read it the normal way, which reports a bad store as
      // "nothing saved".
      return true;
    }
  }

  void _loadOverrides(Object? json) {
    if (json is! Map) {
      return;
    }
    final flags = json['flags'];
    if (flags is Map) {
      for (final MapEntry(:key, :value) in flags.entries) {
        if (key is String && value is Object) {
          _overrideFlags[key] = value;
        }
      }
    }
    final variants = json['variants'];
    if (variants is Map) {
      for (final MapEntry(:key, :value) in variants.entries) {
        if (key is String && value is String) {
          _forcedVariants[key] = value;
        }
      }
    }
  }

  void _listen() {
    _authSubscription = _session.authState.listen((_) {
      _observeEpoch();
      _notify();
    });
  }

  /// Starts the fetch for the current session without waiting for it.
  void start() {
    _observeEpoch();
    unawaited(_fetch());
  }

  /// Stops listening and ignores any fetch still running.
  ///
  /// Neither the subscription's `cancel` nor the controller's `close` is
  /// awaited: a cancelled subscription returns a future from the root zone,
  /// which a caller under fake async (a widget test tearing down the root
  /// container) would wait on forever.
  Future<void> dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    unawaited(_changes.close());
    return Future<void>.value();
  }

  // --- reading -----------------------------------------------------------

  @override
  T value<T extends Object>(FeatureFlag<T> flag) {
    _observeEpoch();
    registry.bindFlag(flag);
    // 1. a local override
    if (_overridesAllowed) {
      final stored = _overrideFlags[flag.key];
      if (stored != null) {
        final decoded = flag.codec.decode(stored);
        if (decoded != null) {
          return decoded;
        }
        _reportOnce(
          'override:${flag.key}',
          'The saved override of ${flag.key} is not a valid $T',
        );
      }
    }
    // 2. the last fetch of this epoch, else 3. the last-known-good body
    final snapshot = _remote ?? _lastKnownGood;
    if (snapshot != null) {
      final raw = snapshot.flags[flag.key];
      if (raw != null) {
        final decoded = flag.codec.decode(raw);
        if (decoded != null) {
          return decoded;
        }
        _reportOnce(
          'remote:${flag.key}',
          'The remote value of ${flag.key} is not a valid $T: '
              '$raw',
        );
      }
    }
    // 4. the default
    return flag.defaultValue;
  }

  @override
  Stream<T> watch<T extends Object>(FeatureFlag<T> flag) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>(
      onListen: () {
        var last = value(flag);
        subscription = _changes.stream.listen((_) {
          final next = value(flag);
          if (next != last) {
            last = next;
            controller.add(next);
          }
        });
        controller.add(last);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  String variant(Experiment experiment) {
    _observeEpoch();
    registry.bindExperiment(experiment);
    final key = experiment.key;
    final variants = experiment.variants;
    // 1. a forced variant
    if (_overridesAllowed) {
      final forced = _forcedVariants[key];
      if (forced != null) {
        if (variants.any((v) => v.name == forced)) {
          return forced;
        }
        _reportOnce(
          'override:$key',
          'The forced variant "$forced" of $key is not declared',
        );
      }
    }
    // 2. and 3. the remote weights, else 4. the declared weights
    var weights = [for (final v in variants) v.weight];
    final snapshot = _remote ?? _lastKnownGood;
    if (snapshot != null && snapshot.experiments.containsKey(key)) {
      final remote = snapshot.experiments[key];
      final scaled = remote == null
          ? null
          : [for (final v in variants) remote[v.name] ?? 0];
      if (scaled != null && scaled.any((w) => w > 0)) {
        weights = scaled;
      } else {
        _reportOnce(
          'remote:$key',
          'The remote weights of $key are malformed or give no declared '
              'variant a positive weight',
        );
      }
    }
    return pickVariant(variants, weights, bucketOf(key, _subject()));
  }

  /// Who experiments bucket: the signed-in user, else the install.
  String _subject() => _session.userId ?? _install();

  String _install() {
    final existing = _installId;
    if (existing != null) {
      return existing;
    }
    final id = _newInstallId();
    _installId = id;
    unawaited(_store.write(flagsInstallIdKey, id));
    return id;
  }

  // --- the session epoch and the fetch -------------------------------------

  /// Notices a new session epoch: forgets the remote values of the old one
  /// (keeping them as last-known-good only for the same user) and starts the
  /// fetch for the new one.
  void _observeEpoch() {
    final epoch = _session.epoch;
    if (_disposed || epoch == _seenEpoch) {
      return;
    }
    final userId = _session.userId;
    _lastKnownGood = userId == _seenUserId ? (_remote ?? _lastKnownGood) : null;
    _remote = null;
    _seenEpoch = epoch;
    _seenUserId = userId;
    unawaited(_fetch());
  }

  @override
  Future<void> refresh() {
    _observeEpoch();
    return _fetch();
  }

  Future<void> _fetch() {
    final epoch = _session.epoch;
    final running = _inFlight;
    if (running != null && running.epoch == epoch) {
      return running.future;
    }
    final future = _runFetch(epoch, _session.userId);
    _inFlight = (epoch: epoch, future: future);
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight?.future, future)) {
          _inFlight = null;
        }
      }),
    );
    return future;
  }

  Future<void> _runFetch(int epoch, String? userId) async {
    try {
      final result = await apiCall<RemoteSnapshot>(() async {
        final response = await _dio.get<Object?>('/v1/flags');
        return RemoteSnapshot.parse(response.data, userId);
      });
      // After the await, before any write: a result for another session is
      // dropped.
      if (_disposed || epoch != _session.epoch) {
        return;
      }
      final snapshot = result.getOrNull();
      if (snapshot == null) {
        _warn(
          'fetch failed: '
          '${result.fold((_) => '', (failure) => failure.message)}',
        );
        return;
      }
      _remote = snapshot;
      _notify();
      final saved = await _store.write(flagsCacheKey, snapshot.toJson());
      saved.fold(
        (_) {},
        (failure) => _warn('could not save the cache: $failure'),
      );
    } on Object catch (error) {
      // Nothing escapes: a failed fetch keeps the current values.
      _warn('fetch failed: $error');
    }
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  void _warn(String message) => unawaited(
    _monitoring?.log('feature_flags: $message', level: LogLevel.warning),
  );

  /// Reports [message] the first time [id] is seen, and never again.
  void _reportOnce(String id, String message) {
    if (_reported.add(id)) {
      _warn(message);
    }
  }

  // --- overrides ---------------------------------------------------------

  @override
  bool get isEnabled => _overridesAllowed;

  Result<void, FlagOverrideFailure>? _rejected() => _overridesAllowed
      ? null
      : failure(
          FlagOverrideFailure(
            FlagOverrideFailureReason.releaseEnvironment,
            'Overrides are not accepted in the "$_env" environment',
          ),
        );

  @override
  Future<Result<void, FlagOverrideFailure>> set<T extends Object>(
    FeatureFlag<T> flag,
    T value,
  ) async {
    final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }
    registry.bindFlag(flag);
    _overrideFlags[flag.key] = flag.codec.encode(value);
    _notify();
    return _saveOverrides();
  }

  @override
  Future<Result<void, FlagOverrideFailure>> clear<T extends Object>(
    FeatureFlag<T> flag,
  ) async {
    final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }
    _overrideFlags.remove(flag.key);
    _notify();
    return _saveOverrides();
  }

  @override
  Future<Result<void, FlagOverrideFailure>> forceVariant(
    Experiment experiment,
    String variant,
  ) async {
    final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }
    if (!experiment.variants.any((v) => v.name == variant)) {
      return failure(
        FlagOverrideFailure(
          FlagOverrideFailureReason.unknownVariant,
          '${experiment.key} has no variant "$variant"',
        ),
      );
    }
    registry.bindExperiment(experiment);
    _forcedVariants[experiment.key] = variant;
    _notify();
    return _saveOverrides();
  }

  @override
  Future<Result<void, FlagOverrideFailure>> clearVariant(
    Experiment experiment,
  ) async {
    final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }
    _forcedVariants.remove(experiment.key);
    _notify();
    return _saveOverrides();
  }

  @override
  Future<Result<void, FlagOverrideFailure>> clearAll() async {
    final rejected = _rejected();
    if (rejected != null) {
      return rejected;
    }
    _overrideFlags.clear();
    _forcedVariants.clear();
    _notify();
    return _saveOverrides();
  }

  Future<Result<void, FlagOverrideFailure>> _saveOverrides() async {
    final saved = _overrideFlags.isEmpty && _forcedVariants.isEmpty
        ? await _store.delete(flagsOverridesKey)
        : await _store.write(flagsOverridesKey, {
            'flags': Map<String, Object>.of(_overrideFlags),
            'variants': Map<String, String>.of(_forcedVariants),
          });
    return saved.fold(
      (_) => success(null),
      (f) => failure(
        FlagOverrideFailure(FlagOverrideFailureReason.storage, f.toString()),
      ),
    );
  }
}

String _randomInstallId() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 16; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}
