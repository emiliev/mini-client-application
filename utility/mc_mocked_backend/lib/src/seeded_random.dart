/// SplitMix64 with named forks (plan 01 §5 "Determinism").
///
/// An entity is a pure function of `(seed, domain, index)`: fork by domain
/// name, then by `index`, and read from the fork.
final class SplitMix64 {
  SplitMix64(int seed) : _state = seed;

  int _state;

  /// The next 64 bits (wrapping, Dart VM `int`).
  int nextInt64() {
    _state += -0x61c8864680b583eb; // 0x9E3779B97F4A7C15
    var z = _state;
    z = (z ^ (z >>> 30)) * -0x40a7b892e31b1a47; // 0xBF58476D1CE4E5B9
    z = (z ^ (z >>> 27)) * -0x6b2fb644ecceee15; // 0x94D049BB133111EB
    return z ^ (z >>> 31);
  }

  /// A uniform integer in `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextInt64() >>> 1) % max;
  }

  /// A uniform double in `[0, 1)`.
  double nextDouble() => (nextInt64() >>> 11) / 9007199254740992.0;

  /// An independent generator named [name]. Forking never advances this one.
  SplitMix64 fork(String name) {
    var h = -0x340d631b7bdddcdb; // FNV-1a 64 offset basis, 0xCBF29CE484222325
    for (final unit in name.codeUnits) {
      h = (h ^ unit) * 0x100000001b3;
    }
    return SplitMix64(SplitMix64(_state ^ h).nextInt64());
  }
}
