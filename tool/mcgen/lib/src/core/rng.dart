// Deterministic randomness for mcgen (plan 02 section 2.5, ADR-0016).
//
// Never `dart:math` `Random`: its sequence is not guaranteed across SDK
// versions. Everything here is 64-bit integer arithmetic, which wraps on the
// Dart VM (mcgen never runs on the web), and `>>>` is the unsigned shift.

import 'dart:convert';

/// FNV-1a, 64 bit, over the UTF-8 bytes of [text].
int fnv1a64(String text) => fnv1a64Bytes(utf8.encode(text));

/// FNV-1a, 64 bit, over [bytes].
int fnv1a64Bytes(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b & 0xff;
    hash *= 0x100000001b3;
  }
  return hash;
}

/// The SplitMix64 output function applied to [z] (one finalising step).
int splitMix64Mix(int z) {
  var x = z;
  x = (x ^ (x >>> 30)) * 0xbf58476d1ce4e5b9;
  x = (x ^ (x >>> 27)) * 0x94d049bb133111eb;
  return x ^ (x >>> 31);
}

/// Formats a 64-bit value as `0x` and 16 lower-case hex digits.
String hex64(int v) {
  final hi = (v >>> 32).toRadixString(16).padLeft(8, '0');
  final lo = (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '0x$hi$lo';
}

/// Steele, Lea and Flood's SplitMix64.
class SplitMix64 {
  SplitMix64(int seed) : _state = seed;

  int _state;

  /// The next 64-bit value (any bit pattern, so possibly negative in Dart).
  int next() {
    _state += 0x9e3779b97f4a7c15;
    return splitMix64Mix(_state);
  }
}

/// A named, forkable random stream.
///
/// [fork] derives a child from this stream's *seed* and the child's name only:
/// it never consumes a draw. Adding a new fork, or drawing more values from a
/// parent, therefore never changes what an existing fork produces. Forking the
/// same name twice gives the same stream.
class Rng {
  Rng._(this.seed, this.path) : _gen = SplitMix64(seed);

  /// The stream for [module]: seeded by `fnv1a64("$globalSeed/$module/$seedSalt")`.
  factory Rng.forModule({
    required int globalSeed,
    required String module,
    required int seedSalt,
  }) => Rng._(fnv1a64('$globalSeed/$module/$seedSalt'), module);

  /// A root stream with an explicit [seed] (tests and tools).
  factory Rng.seeded(int seed, {String path = 'root'}) => Rng._(seed, path);

  /// This stream's seed.
  final int seed;

  /// The fork path from the root, `/`-separated (diagnostics only).
  final String path;

  final SplitMix64 _gen;

  /// The child stream called [name].
  Rng fork(String name) {
    if (name.isEmpty || name.contains('/')) {
      throw ArgumentError.value(name, 'name', 'must be non-empty, without "/"');
    }
    return Rng._(splitMix64Mix(seed ^ fnv1a64(name)), '$path/$name');
  }

  /// The next raw 64-bit value.
  int nextInt64() => _gen.next();

  /// A uniform integer in `[0, bound)`, without modulo bias.
  int nextInt(int bound) {
    if (bound <= 0) throw ArgumentError.value(bound, 'bound', 'must be > 0');
    const mask = 0x7fffffffffffffff;
    while (true) {
      final r = _gen.next() & mask;
      final v = r % bound;
      // Java's SplittableRandom test: rejects the incomplete last bucket.
      // `r - v + (bound - 1)` overflows to a negative value exactly then.
      if (r - v + (bound - 1) >= 0) return v;
    }
  }

  /// A uniform integer in `[min, max]` (both inclusive).
  int nextIntInRange(int min, int max) {
    if (max < min) throw ArgumentError('max ($max) < min ($min)');
    return min + nextInt(max - min + 1);
  }

  /// A uniform double in `[0, 1)` with 53 random bits.
  double nextDouble() => (_gen.next() >>> 11) * (1.0 / 9007199254740992.0);

  /// True with probability [p].
  bool chance(double p) => nextDouble() < p;

  /// One element of [items], uniformly.
  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('pick from an empty list');
    return items[nextInt(items.length)];
  }

  /// A Fisher-Yates shuffled copy of [items].
  List<T> shuffled<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = out[i];
      out[i] = out[j];
      out[j] = t;
    }
    return out;
  }
}
