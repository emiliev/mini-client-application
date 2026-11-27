// T-0065-AC3 (determinism and RNG), part 1: the generators against a golden
// table that an independent BigInt implementation reproduces in this test.

import 'dart:convert';

import 'package:mcgen/mcgen.dart';
import 'package:mcgen/src/emit/utility_hello/utility_hello.dart';
import 'package:test/test.dart';

final _mod = BigInt.one << 64;

BigInt _u(int v) => BigInt.from(v).toUnsigned(64);

/// FNV-1a 64 in arbitrary precision: shares no code with lib/.
BigInt refFnv(String s) {
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  for (final b in utf8.encode(s)) {
    h = ((h ^ BigInt.from(b)) * prime) % _mod;
  }
  return h;
}

BigInt refMix(BigInt z0) {
  var z = z0;
  z = ((z ^ (z >> 30)) * BigInt.parse('bf58476d1ce4e5b9', radix: 16)) % _mod;
  z = ((z ^ (z >> 27)) * BigInt.parse('94d049bb133111eb', radix: 16)) % _mod;
  return z ^ (z >> 31);
}

List<BigInt> refSplitMix(BigInt seed, int n) {
  var s = seed;
  final golden = BigInt.parse('9e3779b97f4a7c15', radix: 16);
  return [
    for (var i = 0; i < n; i++) refMix(s = (s + golden) % _mod),
  ];
}

BigInt _hex(String h) => BigInt.parse(h.substring(2), radix: 16);

void main() {
  group('T-0065-AC3 golden table', () {
    // FNV-1a 64: "", "a" and "foobar" are the FNV reference vectors; the
    // last is mc_hello's module seed (global seed 20261127, salt 0).
    const fnvTable = {
      '': '0xcbf29ce484222325',
      'a': '0xaf63dc4c8601ec8c',
      'foobar': '0x85944171f73967e8',
      '20261127/mc_hello/0': '0x562a6946d495a023',
    };
    // SplitMix64: seed 0 is Vigna's splitmix64.c reference output.
    const smTable = {
      0: ['0xe220a8397b1dcdaf', '0x6e789e6aa1b965f4', '0x06c45d188009454f'],
      1234567: [
        '0x599ed017fb08fc85',
        '0x2c73f08458540fa5',
        '0x883ebce5a3f27c77',
      ],
    };

    test('T-0065-AC3 fnv1a64 matches the table and the BigInt reference', () {
      fnvTable.forEach((input, expected) {
        expect(hex64(fnv1a64(input)), expected, reason: 'fnv1a64("$input")');
        expect(
          refFnv(input),
          _hex(expected),
          reason: 'reference fnv("$input")',
        );
      });
    });

    test(
      'T-0065-AC3 SplitMix64 matches the table and the BigInt reference',
      () {
        smTable.forEach((seed, expected) {
          final g = SplitMix64(seed);
          expect(
            [for (var i = 0; i < 3; i++) hex64(g.next())],
            expected,
            reason: 'seed $seed',
          );
          expect(refSplitMix(BigInt.from(seed), 3), [
            for (final e in expected) _hex(e),
          ]);
        });
        // A seed with the top bit set (negative as a Dart int) agrees as well.
        final g = SplitMix64(0xcbf29ce484222325);
        expect([
          for (var i = 0; i < 5; i++) _u(g.next()),
        ], refSplitMix(_u(0xcbf29ce484222325), 5));
      },
    );

    test(
      'T-0065-AC3 the module seed is fnv1a64 of "globalSeed/module/salt"',
      () {
        final r = Rng.forModule(
          globalSeed: 20261127,
          module: 'mc_hello',
          seedSalt: 0,
        );
        expect(hex64(r.seed), '0x562a6946d495a023');
        expect(
          [for (var i = 0; i < 3; i++) hex64(r.nextInt64())],
          ['0x1e805aa9b8ce6d13', '0x3ec3173d08f75631', '0xfcf3cf18c007603d'],
        );
        expect(refSplitMix(refFnv('20261127/mc_hello/0'), 3), [
          _hex('0x1e805aa9b8ce6d13'),
          _hex('0x3ec3173d08f75631'),
          _hex('0xfcf3cf18c007603d'),
        ]);
        final salted = Rng.forModule(
          globalSeed: 20261127,
          module: 'mc_hello',
          seedSalt: 1,
        );
        expect(_u(salted.seed), refFnv('20261127/mc_hello/1'));
      },
    );

    test('T-0065-AC3 a fork is mix(parent seed ^ fnv1a64(name))', () {
      final r = Rng.seeded(42);
      expect(hex64(r.fork('a').seed), '0x2c987fe0b5e27e11');
      expect(hex64(r.fork('b').seed), '0x87c28d8a5ee753bb');
      expect(hex64(r.fork('a').fork('b').seed), '0xda508c467da35222');
      expect(_u(r.fork('a').seed), refMix(BigInt.from(42) ^ refFnv('a')));
      expect(r.fork('a').path, 'root/a');
    });

    test('T-0065-AC3 nextInt and nextDouble are fixed for a seed', () {
      final d = Rng.seeded(7);
      expect(
        [for (var i = 0; i < 8; i++) d.nextInt(10)],
        [7, 4, 8, 5, 4, 5, 8, 2],
      );
      expect(Rng.seeded(7).nextDouble(), 0.3898297483912715);
      expect(
        Rng.forModule(
          globalSeed: 20261127,
          module: 'mc_hello',
          seedSalt: 0,
        ).fork('entities').fork('Greeting').pick(salutations),
        'Welcome',
      );
    });
  });

  group('T-0065-AC3 forking is stable', () {
    List<int> draws(Rng r) => [for (var i = 0; i < 6; i++) r.nextInt64()];

    test('T-0065-AC3 adding a fork does not change existing forks', () {
      final before = Rng.seeded(99);
      final a1 = draws(before.fork('entities').fork('Character'));
      final b1 = draws(before.fork('screens'));

      final after = Rng.seeded(99);
      // A new knob: a new fork, created first and drawn from heavily.
      draws(after.fork('mixins'));
      draws(after.fork('entities').fork('Comic'));
      final b2 = draws(after.fork('screens'));
      final a2 = draws(after.fork('entities').fork('Character'));
      expect(a2, a1);
      expect(b2, b1);
    });

    test('T-0065-AC3 drawing from a parent does not change its forks', () {
      final r = Rng.seeded(5);
      final f1 = draws(r.fork('x'));
      draws(r);
      draws(r);
      expect(draws(r.fork('x')), f1);
    });

    test('T-0065-AC3 different names give different streams', () {
      final r = Rng.seeded(5);
      expect(draws(r.fork('x')), isNot(draws(r.fork('y'))));
      expect(() => r.fork(''), throwsArgumentError);
      expect(() => r.fork('a/b'), throwsArgumentError);
    });

    test('T-0065-AC3 nextInt is unbiased in its bounds', () {
      final r = Rng.seeded(3);
      final counts = List.filled(3, 0);
      for (var i = 0; i < 3000; i++) {
        counts[r.nextInt(3)]++;
      }
      expect(
        counts.every((c) => c > 900 && c < 1100),
        isTrue,
        reason: '$counts',
      );
      expect(() => r.nextInt(0), throwsArgumentError);
      final big = Rng.seeded(3);
      for (var i = 0; i < 100; i++) {
        final v = big.nextInt(0x7fffffffffffffff);
        expect(v >= 0 && v < 0x7fffffffffffffff, isTrue);
      }
      expect(Rng.seeded(3).nextIntInRange(5, 5), 5);
      expect(Rng.seeded(3).shuffled([1, 2, 3, 4]).toSet(), {1, 2, 3, 4});
    });
  });
}
