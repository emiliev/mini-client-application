import 'seeded_random.dart';

/// How long a response takes (plan 01 §5 "Latency").
///
/// The delay is a pure function of the profile and the generator, so a seeded
/// backend always waits the same time for request `n`.
final class LatencyProfile {
  const LatencyProfile._(this.base, this.jitter);

  /// Tests: no delay at all (no timer is created).
  static const none = LatencyProfile._(Duration.zero, Duration.zero);

  /// Development: `base` plus a seeded value in `[0, jitter)`.
  const LatencyProfile.realistic({
    Duration base = const Duration(milliseconds: 120),
    Duration jitter = const Duration(milliseconds: 80),
  }) : this._(base, jitter);

  /// A constant, slow response.
  const LatencyProfile.slow([
    Duration delay = const Duration(milliseconds: 1500),
  ]) : this._(delay, Duration.zero);

  final Duration base;
  final Duration jitter;

  /// The delay for a request that draws from [rng].
  Duration delayFor(SplitMix64 rng) {
    if (jitter == Duration.zero) return base;
    return base + Duration(microseconds: rng.nextInt(jitter.inMicroseconds));
  }
}
