/// One request seen by the backend (the diagnostics "traffic" feed).
final class TrafficEntry {
  const TrafficEntry({
    required this.method,
    required this.path,
    required this.status,
    required this.duration,
    this.error,
  });

  final String method;
  final String path;

  /// The HTTP status, or null when the request threw (timeout, offline).
  final int? status;

  /// The simulated time the request took (latency plus injected delay).
  /// Deterministic for a seed, and unaffected by the host machine's speed.
  final Duration duration;

  /// The Dio exception type name when the request threw.
  final String? error;

  @override
  String toString() =>
      '$method $path -> ${status ?? error} in ${duration.inMilliseconds} ms';
}
