import 'dart:convert';
import 'dart:math';

import 'package:mc_feature_flags/mc_feature_flags.dart';
import 'package:test/test.dart';

import 'rig.dart';

// --- An independent implementation of the documented bucketing -------------
//
// Nothing here calls the kit. FNV-1a is done with BigInt, byte by byte, with
// the textbook constants; the variant is chosen by comparing fractions
// (`(bucket + 1) * total <= cumulative * 10000`), which is the same rule as
// the kit's `bucket < cumulative * 10000 ~/ total` written another way.

final BigInt _offset = BigInt.parse('2166136261');
final BigInt _prime = BigInt.parse('16777619');
final BigInt _mask = BigInt.parse('4294967295');

int oracleBucket(String experiment, String subject) {
  var hash = _offset;
  for (final byte in utf8.encode('$experiment:$subject')) {
    hash = ((hash ^ BigInt.from(byte)) * _prime) & _mask;
  }
  return (hash % BigInt.from(10000)).toInt();
}

String oraclePick(Map<String, int> weights, int bucket) {
  final total = weights.values.fold(0, (a, b) => a + b);
  var cumulative = 0;
  for (final MapEntry(:key, :value) in weights.entries) {
    cumulative += value;
    if ((bucket + 1) * total <= cumulative * 10000) {
      return key;
    }
  }
  return weights.keys.first;
}

const Map<String, Map<String, int>> _experiments = {
  'store_home_layout': {'control': 5000, 'compact': 3000, 'rich': 2000},
  'trivia_hint': {'control': 10000, 'hint': 0},
  'checkout_cta': {'a': 1, 'b': 1, 'c': 1},
  'é-exp': {'control': 50, 'b': 50},
};

/// (experiment, subject, bucket, variant): computed once with a separate
/// Python implementation of FNV-1a 32 and the same cumulative rule, and
/// written down here as literals.
const List<(String, String, int, String)> _golden = [
  ('store_home_layout', 'u-100', 4304, 'control'),
  ('store_home_layout', 'u-101', 1923, 'control'),
  ('store_home_layout', 'install-0', 4635, 'control'),
  ('store_home_layout', 'install-1', 7016, 'compact'),
  ('store_home_layout', '', 39, 'control'),
  ('store_home_layout', 'user-é', 5635, 'compact'),
  ('store_home_layout', 'a', 482, 'control'),
  ('store_home_layout', 'b', 2863, 'control'),
  ('store_home_layout', '0123456789abcdef0123456789abcdef', 1959, 'control'),
  ('store_home_layout', 'u-102', 9542, 'rich'),
  ('trivia_hint', 'u-100', 237, 'control'),
  ('trivia_hint', 'u-101', 2618, 'control'),
  ('trivia_hint', 'install-0', 8030, 'control'),
  ('trivia_hint', 'install-1', 5649, 'control'),
  ('trivia_hint', '', 1504, 'control'),
  ('trivia_hint', 'user-é', 7526, 'control'),
  ('checkout_cta', 'u-100', 35, 'a'),
  ('checkout_cta', 'u-101', 2416, 'a'),
  ('checkout_cta', 'install-0', 7420, 'c'),
  ('checkout_cta', 'install-1', 5039, 'b'),
  ('checkout_cta', '', 6082, 'b'),
  ('checkout_cta', 'user-é', 6456, 'b'),
  ('é-exp', 'u-100', 2396, 'control'),
  ('é-exp', 'u-101', 15, 'control'),
  ('é-exp', 'install-0', 2479, 'control'),
  ('é-exp', 'install-1', 4860, 'control'),
  ('é-exp', '', 2059, 'control'),
  ('é-exp', 'user-é', 3655, 'control'),
];

Experiment _experiment(String key) => Experiment(
  key: key,
  variants: [
    for (final MapEntry(:key, :value) in _experiments[key]!.entries)
      ExperimentVariant(key, value),
  ],
);

List<Object?> _remote(String key, Map<String, Object?> weights) => [
  {
    'key': key,
    'variants': [
      for (final MapEntry(:key, :value) in weights.entries)
        {'name': key, 'weight': value},
    ],
  },
];

void main() {
  final rigs = <Rig>[];
  Future<Rig> make({
    String env = 'dev',
    StubFlagsDomain? stub,
    String Function()? newInstallId,
    bool start = false,
  }) async {
    final rig = await Rig.create(
      env: env,
      stub: stub,
      newInstallId: newInstallId,
      start: start,
    );
    rigs.add(rig);
    return rig;
  }

  tearDown(() async {
    for (final rig in rigs) {
      await rig.dispose();
    }
    rigs.clear();
  });

  group('T-0052-AC2 bucketing is stable', () {
    test('T-0052-AC2 the golden table: at least 20 rows, the kit, the '
        'in-test oracle and the literals agree', () {
      expect(_golden.length, greaterThanOrEqualTo(20));
      for (final (experiment, subject, bucket, variant) in _golden) {
        final reason = '$experiment:$subject';
        expect(oracleBucket(experiment, subject), bucket, reason: reason);
        expect(bucketOf(experiment, subject), bucket, reason: reason);
        final weights = _experiments[experiment]!;
        expect(oraclePick(weights, bucket), variant, reason: reason);
        final declared = _experiment(experiment).variants;
        expect(
          pickVariant(declared, [for (final v in declared) v.weight], bucket),
          variant,
          reason: reason,
        );
      }
      // The table reaches every variant of the three-way experiment.
      expect(
        {
          for (final (e, _, _, v) in _golden)
            if (e == 'store_home_layout') v,
        },
        {'control', 'compact', 'rich'},
      );
    });

    test('T-0052-AC2 the golden table through the public API: the variant '
        'of a signed-in user is the table\'s', () async {
      final rig = await make();
      for (final (experiment, subject, _, variant) in _golden) {
        if (subject.isEmpty) {
          continue;
        }
        await rig.signIn(subject);
        expect(
          rig.flags.variant(_experiment(experiment)),
          variant,
          reason: '$experiment:$subject',
        );
      }
    });

    test('T-0052-AC2 the hash is FNV-1a 32 and is not String.hashCode: known '
        'vectors', () {
      // Published FNV-1a 32-bit test vectors.
      expect(fnv1a32(const []), 0x811c9dc5);
      expect(fnv1a32(utf8.encode('a')), 0xe40c292c);
      expect(fnv1a32(utf8.encode('foobar')), 0xbf9cf968);
      expect(bucketCount, 10000);
      // Detector control: a hash that uses String.hashCode disagrees.
      expect('store_home_layout:u-100'.hashCode % 10000, isNot(4304));
    });

    test('T-0052-AC2 the same subject gets the same variant on a new '
        'instance and after a restart, anonymous or signed in', () async {
      final first = await make();
      await first.signIn('u-102');
      final signedIn = first.flags.variant(storeHomeLayout);
      expect(signedIn, 'rich');
      var made = 0;
      final anonymous = await make(newInstallId: () => 'install-${++made}');
      final anonymousVariant = anonymous.flags.variant(storeHomeLayout);
      expect(anonymousVariant, 'compact');
      expect(made, 1);
      await anonymous.settle();

      final restarted = await anonymous.relaunch(start: false);
      rigs.add(restarted);
      // The supplier would now give another id: the saved one is used.
      expect(restarted.flags.variant(storeHomeLayout), anonymousVariant);

      final again = await first.relaunch(start: false);
      rigs.add(again);
      expect(again.session.userId, 'u-102');
      expect(again.flags.variant(storeHomeLayout), signedIn);
      for (var i = 0; i < 5; i++) {
        expect(again.flags.variant(storeHomeLayout), signedIn);
      }
    });

    test('T-0052-AC2 an anonymous install keeps one persisted id, made '
        'once', () async {
      var made = 0;
      final rig = await make(
        newInstallId: () {
          made++;
          return 'install-$made';
        },
      );
      rig.flags.variant(storeHomeLayout);
      rig.flags.variant(storeHomeLayout);
      await rig.settle();
      expect(made, 1);
      expect(
        (await rig.store.read(flagsInstallIdKey)).getOrNull(),
        'install-1',
      );
      final restarted = await rig.relaunch(
        start: false,
        // The relaunch reuses the id supplier above; it must not be asked.
      );
      rigs.add(restarted);
      restarted.flags.variant(storeHomeLayout);
      expect(made, 1, reason: 'the saved id is reused');
    });

    test(
      'T-0052-AC2 changing the user changes the subject: each user is '
      'bucketed on its own id, and signing out goes back to the install',
      () async {
        final rig = await make(newInstallId: () => 'install-1');
        expect(
          rig.flags.variant(storeHomeLayout),
          'compact',
          reason: 'install',
        );
        await rig.signIn('u-102');
        expect(rig.flags.variant(storeHomeLayout), 'rich');
        await rig.signIn('u-100');
        expect(rig.flags.variant(storeHomeLayout), 'control');
        await rig.signIn('user-é');
        expect(rig.flags.variant(storeHomeLayout), 'compact');
        await rig.signOut();
        expect(rig.flags.variant(storeHomeLayout), 'compact');
        expect(
          oracleBucket('store_home_layout', 'install-1'),
          isNot(oracleBucket('store_home_layout', 'u-102')),
        );
      },
    );

    test('T-0052-AC2 the install id does not depend on the experiment, the '
        'experiment key does: the same subject is in different buckets', () {
      final buckets = {
        for (final e in _experiments.keys) bucketOf(e, 'u-100'),
      };
      expect(buckets.length, greaterThan(2));
    });
  });

  group('T-0052-AC2 the split follows the weights', () {
    void expectSplit(
      Map<String, int> weights,
      Iterable<String> subjects,
      String experiment, {
      Map<String, int>? expectedWeights,
    }) {
      final expectedShare = expectedWeights ?? weights;
      final total = expectedShare.values.fold(0, (a, b) => a + b);
      final declared = [
        for (final MapEntry(:key, :value) in weights.entries)
          ExperimentVariant(key, value),
      ];
      final counts = {for (final k in weights.keys) k: 0};
      var n = 0;
      for (final subject in subjects) {
        final variant = pickVariant(declared, [
          for (final v in declared) v.weight,
        ], bucketOf(experiment, subject));
        counts[variant] = counts[variant]! + 1;
        n++;
      }
      expect(n, 10000);
      for (final MapEntry(:key, :value) in expectedShare.entries) {
        final expected = value * 100 / total;
        final actual = counts[key]! * 100 / n;
        expect(
          (actual - expected).abs(),
          lessThanOrEqualTo(2),
          reason: '$experiment/$key: $actual % vs $expected %',
        );
      }
    }

    test('T-0052-AC2 over 10,000 synthetic subjects the split is within '
        '2 % of the weights (sequential ids, user ids, random ids)', () {
      final random = Random(42);
      final schemes = <String, List<String>>{
        'sequential': [for (var i = 0; i < 10000; i++) 'user-$i'],
        'u-': [for (var i = 0; i < 10000; i++) 'u-${100 + i}'],
        'random hex': [
          for (var i = 0; i < 10000; i++)
            [
              for (var j = 0; j < 16; j++)
                random.nextInt(256).toRadixString(16).padLeft(2, '0'),
            ].join(),
        ],
      };
      for (final MapEntry(:key, :value) in schemes.entries) {
        for (final MapEntry(key: e, value: w) in _experiments.entries) {
          expectSplit(w, value, e);
        }
        expect(value.length, 10000, reason: key);
      }
    });

    test('T-0052-AC2 negative control: the split check fails for the wrong '
        'weights', () {
      expect(
        () => expectSplit(
          {'control': 9000, 'compact': 1000},
          [for (var i = 0; i < 10000; i++) 'user-$i'],
          'store_home_layout',
          expectedWeights: {'control': 5000, 'compact': 5000},
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('T-0052-AC2 a variant with weight 0 never gets a subject: the '
        'declared one, a remote one, and one in the middle', () async {
      final declared = _experiment('trivia_hint').variants;
      for (var i = 0; i < 10000; i++) {
        expect(
          pickVariant(declared, [10000, 0], bucketOf('trivia_hint', 's$i')),
          'control',
        );
        expect(
          pickVariant(declared, [0, 10000], bucketOf('trivia_hint', 's$i')),
          'hint',
        );
      }
      final three = _experiment('store_home_layout').variants;
      for (var i = 0; i < 10000; i++) {
        expect(
          pickVariant(three, [5000, 0, 5000], bucketOf('x', 's$i')),
          isNot('compact'),
        );
      }
      // Every bucket, with a zero in each position.
      for (var b = 0; b < 10000; b++) {
        expect(pickVariant(three, [0, 1, 1], b), isNot('control'));
        expect(pickVariant(three, [1, 0, 1], b), isNot('compact'));
        expect(pickVariant(three, [1, 1, 0], b), isNot('rich'));
      }
      // And through the API with remote weights.
      final rig = await make();
      rig.stub.experiments = _remote('store_home_layout', {
        'control': 0,
        'compact': 0,
        'rich': 7,
      });
      await rig.flags.refresh();
      for (final subject in ['u-100', 'u-101', 'u-102', 'a', 'b', 'user-é']) {
        await rig.signIn(subject);
        rig.stub.experiments = _remote('store_home_layout', {
          'control': 0,
          'compact': 0,
          'rich': 7,
        });
        await rig.flags.refresh();
        expect(rig.flags.variant(storeHomeLayout), 'rich', reason: subject);
      }
    });

    test('T-0052-AC2 no positive weight: the first variant (the control) '
        'is the answer', () {
      final three = _experiment('store_home_layout').variants;
      for (final b in [0, 1, 4999, 5000, 9999]) {
        expect(pickVariant(three, [0, 0, 0], b), 'control');
      }
    });

    test(
      'T-0052-AC2 boundaries: the scaled cumulative weight is exclusive',
      () {
        final three = _experiment('store_home_layout').variants;
        const w = [5000, 3000, 2000];
        expect(pickVariant(three, w, 4999), 'control');
        expect(pickVariant(three, w, 5000), 'compact');
        expect(pickVariant(three, w, 7999), 'compact');
        expect(pickVariant(three, w, 8000), 'rich');
        expect(pickVariant(three, w, 9999), 'rich');
        // Relative weights are scaled to 10000.
        expect(pickVariant(three, [1, 1, 2], 2499), 'control');
        expect(pickVariant(three, [1, 1, 2], 2500), 'compact');
        expect(pickVariant(three, [1, 1, 2], 4999), 'compact');
        expect(pickVariant(three, [1, 1, 2], 5000), 'rich');
      },
    );
  });

  group('T-0052-AC2 remote weights and forced variants', () {
    test('T-0052-AC2 remote weights replace the declared ones', () async {
      final rig = await make();
      await rig.signIn('u-100');
      expect(rig.flags.variant(storeHomeLayout), 'control');
      await rig.flags.refresh(); // ends the fetch that the read started
      rig.stub.experiments = _remote('store_home_layout', {
        'control': 0,
        'compact': 1,
        'rich': 0,
      });
      await rig.flags.refresh();
      expect(rig.flags.variant(storeHomeLayout), 'compact');
    });

    test('T-0052-AC2 a declared variant the remote entry omits has weight 0, '
        'and a remote variant that is not declared is ignored', () async {
      final rig = await make();
      rig.stub.experiments = _remote('store_home_layout', {
        'rich': 1,
        'surprise': 100000,
      });
      await rig.signIn('u-100');
      await rig.flags.refresh();
      expect(rig.flags.variant(storeHomeLayout), 'rich');
      expect(rig.reports, isEmpty);
    });

    test(
      'T-0052-AC2 malformed remote weights, or none for any declared '
      'variant, fall back to the declared weights and are reported once',
      () async {
        final rig = await make();
        await rig.signIn('u-100');
        for (final entries in [
          _remote('store_home_layout', {'control': 'heavy', 'rich': 1}),
          _remote('store_home_layout', {'control': -1, 'rich': 1}),
          _remote('store_home_layout', {'control': 1.5, 'rich': 1}),
          _remote('store_home_layout', {'surprise': 1}),
          _remote('store_home_layout', {'control': 0, 'rich': 0}),
          <Object?>[
            {'key': 'store_home_layout', 'variants': <Object?>[]},
          ],
          <Object?>[
            {'key': 'store_home_layout', 'variants': 'many'},
          ],
          <Object?>[
            {
              'key': 'store_home_layout',
              'variants': <Object?>[5],
            },
          ],
        ]) {
          rig.stub.experiments = entries;
          await rig.flags.refresh();
          // u-100 is control under the declared weights.
          expect(
            rig.flags.variant(storeHomeLayout),
            'control',
            reason: '$entries',
          );
        }
        await rig.settle();
        expect(
          rig.reports.where((m) => m.contains('store_home_layout')).length,
          1,
        );
      },
    );

    test('T-0052-AC2 the last-known-good weights are used after a restart '
        'with the backend failing', () async {
      final first = await make();
      first.stub.experiments = _remote('store_home_layout', {
        'control': 0,
        'compact': 0,
        'rich': 1,
      });
      await first.signIn('u-100');
      await first.flags.refresh();
      expect(first.flags.variant(storeHomeLayout), 'rich');
      final second = await first.relaunch(start: false);
      rigs.add(second);
      expect(second.flags.variant(storeHomeLayout), 'rich');
      // Control: without the cache the declared weights give control.
      await second.store.delete(flagsCacheKey);
      final third = await second.relaunch(start: false);
      rigs.add(third);
      expect(third.flags.variant(storeHomeLayout), 'control');
    });

    test('T-0052-AC2 a forced variant wins over the bucket and over remote '
        'weights, and clearing it restores them', () async {
      final rig = await make();
      await rig.signIn('u-100');
      rig.stub.experiments = _remote('store_home_layout', {
        'control': 1,
        'compact': 0,
        'rich': 0,
      });
      await rig.flags.refresh();
      expect(rig.flags.variant(storeHomeLayout), 'control');
      await rig.flags.forceVariant(storeHomeLayout, 'rich');
      expect(rig.flags.variant(storeHomeLayout), 'rich');
      await rig.signIn('u-101');
      expect(
        rig.flags.variant(storeHomeLayout),
        'rich',
        reason: 'still forced',
      );
      await rig.flags.clearVariant(storeHomeLayout);
      expect(rig.flags.variant(storeHomeLayout), 'control');
    });

    test('T-0052-AC2 an undeclared forced variant is rejected and a stale '
        'saved one is reported once and ignored', () async {
      final rig = await make();
      await rig.signIn('u-100');
      final rejected = await rig.flags.forceVariant(storeHomeLayout, 'nope');
      expect(
        rejected.fold((_) => null, (f) => f.reason),
        FlagOverrideFailureReason.unknownVariant,
      );
      expect(rig.flags.variant(storeHomeLayout), 'control');
      await rig.store.write(flagsOverridesKey, {
        'flags': <String, Object?>{},
        'variants': {'store_home_layout': 'gone'},
      });
      final next = await rig.relaunch(start: false);
      rigs.add(next);
      expect(next.flags.variant(storeHomeLayout), 'control');
      expect(next.flags.variant(storeHomeLayout), 'control');
      expect(
        next.reports.where((m) => m.contains('store_home_layout')).length,
        1,
      );
    });
  });
}
