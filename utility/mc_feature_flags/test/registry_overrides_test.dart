import 'dart:io';

import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

import 'rig.dart';

const FeatureFlag<bool> _twin = FeatureFlag<bool>(
  key: 'store.promo_banner',
  defaultValue: false,
  description: 'Same key, other flag.',
  codec: BoolFlagCodec(),
);
const FeatureFlag<bool> _otherDefault = FeatureFlag<bool>(
  key: 'store.promo_banner',
  defaultValue: false,
  description: 'Shows the promotion banner.',
  codec: BoolFlagCodec(),
);
const FeatureFlag<int> _otherType = FeatureFlag<int>(
  key: 'store.promo_banner',
  defaultValue: 1,
  description: 'Shows the promotion banner.',
  codec: IntFlagCodec(),
);
const FeatureFlag<bool> _blank = FeatureFlag<bool>(
  key: '  ',
  defaultValue: false,
  description: 'No key.',
  codec: BoolFlagCodec(),
);

/// A store whose writes throw at once instead of returning a failed result.
final class _ThrowingStore extends FileStore {
  _ThrowingStore(super.directory);

  @override
  Future<Result<void, StorageFailure>> write(String key, Object? value) =>
      throw StateError('disk on fire');
}

/// A store whose first [failures] writes fail (a failed result).
final class _FlakyStore extends FileStore {
  _FlakyStore(super.directory, {required this.failures});

  int failures;
  int attempts = 0;
  final List<Future<Object?>> pending = [];

  @override
  Future<Result<void, StorageFailure>> write(String key, Object? value) {
    attempts++;
    final Future<Result<void, StorageFailure>> done;
    if (failures > 0) {
      failures--;
      done = Future.value(failure(StorageFailure(key, 'disk full')));
    } else {
      done = super.write(key, value);
    }
    pending.add(done);
    return done;
  }
}

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({String env = 'dev', Directory? dir}) async {
    final rig = await Rig.create(env: env, dir: dir, start: false);
    rigs.add(rig);
    return rig;
  }

  tearDown(() async {
    for (final rig in rigs) {
      await rig.dispose();
    }
    rigs.clear();
  });

  group('T-0052-AC1 review round', () {
    test('T-0052-AC1 set and forceVariant return a failure for a taken or '
        'blank key instead of throwing', () async {
      final rig = await make();
      rig.flags.value(promoBanner); // registers store.promo_banner
      rig.flags.variant(storeHomeLayout);
      FlagOverrideFailureReason? reason(Result<void, FlagOverrideFailure> r) =>
          r.fold((_) => null, (f) => f.reason);
      expect(
        reason(await rig.flags.set(_twin, true)),
        FlagOverrideFailureReason.invalidFlag,
      );
      expect(
        reason(await rig.flags.set(_blank, true)),
        FlagOverrideFailureReason.invalidFlag,
      );
      expect(
        reason(
          await rig.flags.forceVariant(
            const Experiment(
              key: 'store_home_layout',
              variants: [ExperimentVariant('control', 1)],
            ),
            'control',
          ),
        ),
        FlagOverrideFailureReason.invalidFlag,
      );
      expect(
        reason(
          await rig.flags.forceVariant(
            const Experiment(key: ' ', variants: [ExperimentVariant('a', 1)]),
            'a',
          ),
        ),
        FlagOverrideFailureReason.invalidFlag,
      );
      // Nothing was saved or applied.
      expect(rig.store.existsSync(flagsOverridesKey), isFalse);
      expect(rig.flags.value(promoBanner), isTrue);
    });

    test('T-0052-AC2 a flag and an experiment that share a key are both '
        'reported', () async {
      final rig = await make();
      const sharedFlag = FeatureFlag<int>(
        key: 'shared',
        defaultValue: 1,
        description: 'x',
        codec: IntFlagCodec(),
      );
      const sharedExperiment = Experiment(
        key: 'shared',
        variants: [ExperimentVariant('a', 1), ExperimentVariant('b', 1)],
      );
      rig.stub
        ..flags = {'shared': 'wrong type'}
        ..experiments = [
          {'key': 'shared', 'variants': <Object?>[]},
        ];
      await rig.flags.refresh();
      rig.flags.value(sharedFlag);
      rig.flags.variant(sharedExperiment);
      await rig.settle();
      final shared = rig.reports.where((m) => m.contains('shared')).toList();
      expect(shared, hasLength(2));
      expect(shared.any((m) => m.contains('remote value')), isTrue);
      expect(shared.any((m) => m.contains('remote weights')), isTrue);
    });

    test('T-0052-AC2 a failed install-id save warns once and is retried on a '
        'later read', () async {
      final rig = await make();
      final store = _FlakyStore(rig.dir, failures: 2);
      final flags = await FeatureFlags.open(
        dio: rig.dio,
        session: rig.session,
        store: store,
        env: 'dev',
        monitoring: rig.monitoring,
        newInstallId: () => 'install-x',
      );
      flags.variant(storeHomeLayout);
      await Future.wait(store.pending);
      await rig.settle();
      flags.variant(storeHomeLayout); // retry 1: fails again
      await Future.wait(store.pending);
      await rig.settle();
      flags.variant(storeHomeLayout); // retry 2: saved
      await Future.wait(store.pending);
      await rig.settle();
      await Future.wait(store.pending);
      flags.variant(storeHomeLayout); // already saved: no more writes
      await rig.settle();
      await Future.wait(store.pending);
      expect(store.attempts, 3);
      expect(
        rig.reports.where((m) => m.contains('install id')),
        hasLength(1),
        reason: 'warned once',
      );
      expect(
        (await rig.store.read(flagsInstallIdKey)).getOrNull(),
        'install-x',
      );
      await flags.dispose();
    });
  });

  group('T-0052-AC1 the registry', () {
    test('T-0052-AC1 registering a key twice throws, even the same flag', () {
      final registry = FeatureFlagRegistry()..registerFlag(promoBanner);
      expect(
        () => registry.registerFlag(promoBanner),
        throwsA(isA<DuplicateFlagKeyError>()),
      );
      expect(
        () => registry.registerFlag(_twin),
        throwsA(
          isA<DuplicateFlagKeyError>().having(
            (e) => e.key,
            'key',
            'store.promo_banner',
          ),
        ),
      );
      expect(registry.flags, [promoBanner]);
      final experiments = FeatureFlagRegistry()
        ..registerExperiment(storeHomeLayout);
      expect(
        () => experiments.registerExperiment(storeHomeLayout),
        throwsA(isA<DuplicateFlagKeyError>()),
      );
      expect(experiments.experiments, [storeHomeLayout]);
    });

    test('T-0052-AC1 negative control: distinct keys register in order', () {
      final registry = FeatureFlagRegistry()
        ..registerFlag(promoBanner)
        ..registerFlag(pageSize)
        ..registerFlag(accent);
      expect(
        [for (final f in registry.flags) f.key],
        [
          'store.promo_banner',
          'catalogue.page_size',
          'settings.accent',
        ],
      );
    });

    test('T-0052-AC1 using a flag registers it once; the same flag again is '
        'fine, a different flag with its key throws', () async {
      final rig = await make();
      expect(rig.flags.value(promoBanner), isTrue);
      expect(rig.flags.value(promoBanner), isTrue);
      expect(rig.flags.registry.flags, [promoBanner]);
      expect(
        () => rig.flags.value(_twin),
        throwsA(isA<DuplicateFlagKeyError>()),
      );
      expect(
        () => rig.flags.value(_otherType),
        throwsA(isA<DuplicateFlagKeyError>()),
        reason: 'the type is part of the flag',
      );
      expect(
        () => rig.flags.registry.registerFlag(promoBanner),
        throwsA(isA<DuplicateFlagKeyError>()),
        reason: 'explicit registration of a used flag',
      );
      rig.flags.variant(storeHomeLayout);
      rig.flags.variant(storeHomeLayout);
      expect(rig.flags.registry.experiments, [storeHomeLayout]);
      expect(
        () => rig.flags.variant(
          const Experiment(
            key: 'store_home_layout',
            variants: [ExperimentVariant('control', 1)],
          ),
        ),
        throwsA(isA<DuplicateFlagKeyError>()),
      );
    });

    test('T-0052-AC1 a blank key and a malformed experiment are refused', () {
      final registry = FeatureFlagRegistry();
      expect(() => registry.registerFlag(_blank), throwsArgumentError);
      expect(
        () => registry.registerExperiment(
          const Experiment(key: '', variants: [ExperimentVariant('a', 1)]),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.registerExperiment(
          const Experiment(key: 'none', variants: []),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.registerExperiment(
          const Experiment(
            key: 'negative',
            variants: [ExperimentVariant('a', -1)],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => registry.registerExperiment(
          const Experiment(
            key: 'twice',
            variants: [ExperimentVariant('a', 1), ExperimentVariant('a', 2)],
          ),
        ),
        throwsArgumentError,
      );
      expect(registry.experiments, isEmpty);
    });

    test('T-0052-AC1 flags and experiments compare by what they declare', () {
      expect(promoBanner, promoBanner);
      expect(_twin == promoBanner, isFalse);
      expect(_otherType == promoBanner, isFalse);
      expect(_otherDefault == promoBanner, isFalse, reason: 'default differs');
      expect(
        () => FeatureFlagRegistry()
          ..registerFlag(promoBanner)
          ..bindFlag(_otherDefault),
        throwsA(isA<DuplicateFlagKeyError>()),
      );
      expect(promoBanner.hashCode, isNot(_twin.hashCode));
      expect(promoBanner.toString(), 'FeatureFlag<bool>(store.promo_banner)');
      expect(
        const Experiment(
          key: 'e',
          variants: [ExperimentVariant('a', 1)],
        ),
        const Experiment(
          key: 'e',
          variants: [ExperimentVariant('a', 1)],
        ),
      );
      expect(
        const Experiment(
              key: 'e',
              variants: [ExperimentVariant('a', 1)],
            ) ==
            const Experiment(
              key: 'e',
              variants: [ExperimentVariant('a', 2)],
            ),
        isFalse,
      );
      expect(
        const Experiment(key: 'e', variants: [ExperimentVariant('a', 1)]) ==
            const Experiment(
              key: 'e',
              variants: [ExperimentVariant('a', 1), ExperimentVariant('b', 1)],
            ),
        isFalse,
      );
      expect(const ExperimentVariant('a', 1).toString(), 'a:1');
      expect(storeHomeLayout.toString(), 'Experiment(store_home_layout)');
      expect(
        const ExperimentVariant('a', 1).hashCode,
        const ExperimentVariant('a', 1).hashCode,
      );
    });
  });

  group('T-0052-AC1 codecs', () {
    test('T-0052-AC1 each codec accepts its own type and nothing else', () {
      const bool_ = BoolFlagCodec();
      expect(bool_.decode(true), isTrue);
      expect(bool_.decode(false), isFalse);
      expect(bool_.decode(1), isNull);
      expect(bool_.decode('true'), isNull);
      expect(bool_.encode(true), true);
      const int_ = IntFlagCodec();
      expect(int_.decode(3), 3);
      expect(int_.decode(3.5), isNull);
      expect(int_.decode('3'), isNull);
      expect(int_.encode(3), 3);
      const string = StringFlagCodec();
      expect(string.decode('x'), 'x');
      expect(string.decode(1), isNull);
      expect(string.encode('x'), 'x');
      const layout = EnumFlagCodec<Layout>(Layout.values);
      expect(layout.decode('list'), Layout.list);
      expect(layout.decode('List'), isNull);
      expect(layout.decode(1), isNull);
      expect(layout.decode(null), isNull);
      expect(layout.encode(Layout.compact), 'compact');
    });
  });

  group('T-0052-AC1 overrides', () {
    test('T-0052-AC1 set, clear and clearAll change what value reads and '
        'what is saved', () async {
      final rig = await make();
      await rig.flags.set(pageSize, 5);
      await rig.flags.set(promoBanner, false);
      await rig.flags.set(accent, 'teal');
      await rig.flags.set(searchLayout, Layout.grid);
      expect(rig.flags.value(pageSize), 5);
      expect(rig.flags.value(promoBanner), isFalse);
      expect(rig.flags.value(accent), 'teal');
      expect(rig.flags.value(searchLayout), Layout.grid);
      final saved =
          (await rig.store.read(flagsOverridesKey)).getOrNull()! as Map;
      expect(saved['flags'], {
        'catalogue.page_size': 5,
        'store.promo_banner': false,
        'settings.accent': 'teal',
        'search.layout': 'grid',
      });
      await rig.flags.clear(pageSize);
      expect(rig.flags.value(pageSize), 10);
      await rig.flags.clear(pageSize); // a no-op
      await rig.flags.clearAll();
      expect(rig.flags.value(accent), 'blue');
      expect(rig.store.existsSync(flagsOverridesKey), isFalse);
    });

    test('T-0052-AC1 a save failure is returned as a value and the override '
        'stays in memory', () async {
      final tmp = Directory.systemTemp.createTempSync('mc_ff_blocked');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File('${tmp.path}/blocked').writeAsStringSync('x');
      final rig = await make(dir: Directory('${tmp.path}/blocked'));
      for (final result in [
        await rig.flags.set(pageSize, 5),
        await rig.flags.forceVariant(storeHomeLayout, 'rich'),
      ]) {
        expect(
          result.fold((_) => null, (f) => f.reason),
          FlagOverrideFailureReason.storage,
        );
      }
      expect(rig.flags.value(pageSize), 5);
      expect(rig.flags.variant(storeHomeLayout), 'rich');
      await rig.flags.clearAll();
      expect(rig.flags.value(pageSize), 10);
    });

    test('T-0052-AC1 a failure prints its reason', () {
      const failure = FlagOverrideFailure(
        FlagOverrideFailureReason.unknownVariant,
        'no such variant',
      );
      expect(failure.toString(), contains('unknownVariant'));
      expect(failure.toString(), contains('no such variant'));
    });

    test('T-0052-AC1 which environments are release-like', () {
      for (final env in ['dev', 'e2e', 'perf', 'test']) {
        expect(isReleaseLikeEnv(env), isFalse, reason: env);
      }
      for (final env in [
        'release',
        'prod',
        'production',
        'staging',
        'Dev',
        '',
      ]) {
        expect(isReleaseLikeEnv(env), isTrue, reason: env);
      }
    });

    test('T-0052-AC1 a corrupt saved overrides file is ignored', () async {
      final rig = await make();
      for (final junk in <Object?>[
        'junk',
        5,
        {'flags': 5, 'variants': 6},
        {
          'flags': {'catalogue.page_size': null, 3: 4},
          'variants': {'x': 5, 6: 'y'},
        },
      ]) {
        await rig.store.write(flagsOverridesKey, junk);
        final next = await rig.relaunch(start: false);
        rigs.add(next);
        expect(next.flags.value(pageSize), 10, reason: '$junk');
        expect(next.flags.variant(storeHomeLayout), isNotEmpty);
      }
    });
  });

  group('T-0052-AC3 odds and ends of the flags object', () {
    test('T-0052-AC3 the default install id is 32 hex characters, made once '
        'and saved', () async {
      final rig = await make();
      final flags = await FeatureFlags.open(
        dio: rig.dio,
        session: rig.session,
        store: rig.tracking,
        env: 'dev',
      );
      flags.variant(storeHomeLayout);
      flags.variant(storeHomeLayout);
      await rig.settle();
      final saved = (await rig.store.read(flagsInstallIdKey)).getOrNull();
      expect(saved, matches(RegExp(r'^[0-9a-f]{32}$')));
      final again = await FeatureFlags.open(
        dio: rig.dio,
        session: rig.session,
        store: rig.tracking,
        env: 'dev',
      );
      expect(again.variant(storeHomeLayout), flags.variant(storeHomeLayout));
      expect((await rig.store.read(flagsInstallIdKey)).getOrNull(), saved);
      await flags.dispose();
      await again.dispose();
    });

    test('T-0052-AC3 a fetch never throws, even when the store does', () async {
      final rig = await make();
      rig.stub.flags = {'catalogue.page_size': 20};
      final flags = await FeatureFlags.open(
        dio: rig.dio,
        session: rig.session,
        store: _ThrowingStore(rig.dir),
        env: 'dev',
        monitoring: rig.monitoring,
      );
      await expectLater(flags.refresh(), completes);
      expect(flags.value(pageSize), 20, reason: 'applied before the save');
      expect(rig.reports.any((m) => m.contains('disk on fire')), isTrue);
      await flags.dispose();
    });

    test('T-0052-AC1 the duplicate error says which key', () {
      final error = DuplicateFlagKeyError('a.b', 'flag');
      expect(error.toString(), contains('flag key "a.b"'));
      expect(
        const Experiment(
          key: 'e',
          variants: [ExperimentVariant('a', 1)],
        ).hashCode,
        const Experiment(
          key: 'e',
          variants: [ExperimentVariant('a', 1)],
        ).hashCode,
      );
    });
  });
}
