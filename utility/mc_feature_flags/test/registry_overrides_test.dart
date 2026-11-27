import 'dart:io';

import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:test/test.dart';

import 'rig.dart';

const FeatureFlag<bool> _twin = FeatureFlag<bool>(
  key: 'store.promo_banner',
  defaultValue: false,
  description: 'Same key, other flag.',
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
}
