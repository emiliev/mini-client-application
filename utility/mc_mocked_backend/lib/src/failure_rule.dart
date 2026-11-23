import 'package:mc_mocked_backend/src/mock_http.dart';
import 'package:mc_mocked_backend/src/seeded_random.dart';

/// What an injected failure does (P5's failure vocabulary).
sealed class FailureKind {
  const FailureKind();

  /// Dio `connectionTimeout`.
  const factory FailureKind.timeout() = TimeoutFailure;

  /// Dio `connectionError`, as when the device has no network.
  const factory FailureKind.offline() = OfflineFailure;

  /// A response with [status] and an error body.
  const factory FailureKind.http(int status) = HttpFailure;
  const factory FailureKind.notFound() = HttpFailure.notFound;
  const factory FailureKind.unauthorized() = HttpFailure.unauthorized;

  /// A 200 whose body is not valid JSON.
  const factory FailureKind.malformed() = MalformedFailure;

  /// The normal answer, after an additional [delay].
  const factory FailureKind.slow(Duration delay) = SlowFailure;
}

final class TimeoutFailure extends FailureKind {
  const TimeoutFailure();
}

final class OfflineFailure extends FailureKind {
  const OfflineFailure();
}

final class HttpFailure extends FailureKind {
  const HttpFailure(this.status);
  const HttpFailure.notFound() : status = 404;
  const HttpFailure.unauthorized() : status = 401;

  final int status;
}

final class MalformedFailure extends FailureKind {
  const MalformedFailure();
}

final class SlowFailure extends FailureKind {
  const SlowFailure(this.delay);

  final Duration delay;
}

/// When a matching request fails.
sealed class FailureTrigger {
  const FailureTrigger();

  /// Every matching request.
  static const FailureTrigger always = _Always();

  /// The first matching request only.
  static const FailureTrigger once = _Times(1);

  /// The first [n] matching requests.
  const factory FailureTrigger.times(int n) = _Times;

  /// Every matching request after the first [n].
  const factory FailureTrigger.afterCalls(int n) = _AfterCalls;

  /// Each matching request with probability [p], drawn from the seeded PRNG.
  const factory FailureTrigger.probability(double p) = _Probability;

  /// [call] is the 1-based count of matching requests.
  bool fires(int call, SplitMix64 rng);
}

final class _Always extends FailureTrigger {
  const _Always();
  @override
  bool fires(int call, SplitMix64 rng) => true;
}

final class _Times extends FailureTrigger {
  const _Times(this.n);
  final int n;
  @override
  bool fires(int call, SplitMix64 rng) => call <= n;
}

final class _AfterCalls extends FailureTrigger {
  const _AfterCalls(this.n);
  final int n;
  @override
  bool fires(int call, SplitMix64 rng) => call > n;
}

final class _Probability extends FailureTrigger {
  const _Probability(this.p);
  final double p;
  @override
  bool fires(int call, SplitMix64 rng) => rng.nextDouble() < p;
}

/// Method + path pattern + optional query predicate, a [kind] and a
/// [trigger]. The path pattern may use `:name` segments.
final class FailureRule {
  const FailureRule(
    this.method,
    this.path,
    this.kind, [
    this.trigger = FailureTrigger.always,
    this.queryMatches,
  ]);

  /// `GET`, `POST`, ... or `*` for any method.
  final String method;
  final String path;
  final FailureKind kind;
  final FailureTrigger trigger;
  final bool Function(Map<String, String> query)? queryMatches;

  bool matches(MockRequest request) {
    if (method != '*' && method != request.method) {
      return false;
    }
    if (!_pathMatches(path, request.path)) {
      return false;
    }
    return queryMatches?.call(request.query) ?? true;
  }

  static bool _pathMatches(String pattern, String path) {
    final p = pattern.split('/').where((s) => s.isNotEmpty).toList();
    final q = path.split('/').where((s) => s.isNotEmpty).toList();
    if (p.length != q.length) {
      return false;
    }
    for (var i = 0; i < p.length; i++) {
      if (!p[i].startsWith(':') && p[i] != q[i]) {
        return false;
      }
    }
    return true;
  }
}
