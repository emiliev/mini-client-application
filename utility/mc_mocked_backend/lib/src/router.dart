import 'dart:async';

import 'mock_http.dart';

/// What a handler may use besides the request.
final class MockContext {
  MockContext({
    required this.seed,
    required this.clock,
    required this.params,
    required this.store,
  });

  final int seed;

  /// The fixed clock (`2026-01-01T00:00Z` unless configured).
  final DateTime clock;

  /// Values of `:name` path segments.
  final Map<String, String> params;

  /// The backend instance's in-memory store; cleared by `reset()`.
  final Map<String, Object?> store;
}

typedef MockHandler = FutureOr<MockResponse> Function(
  MockRequest request,
  MockContext context,
);

List<String> _split(String path) =>
    path.split('/').where((s) => s.isNotEmpty).toList();

/// One registered route.
final class MockRoute {
  MockRoute(this.method, this.pattern, this.handler)
    : _segments = _split(pattern);

  final String method;
  final String pattern;
  final MockHandler handler;
  final List<String> _segments;

  String get key => '$method $pattern';

  int get _literals => _segments.where((s) => !s.startsWith(':')).length;

  Map<String, String>? _match(String method, List<String> path) {
    if (method != this.method || path.length != _segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < path.length; i++) {
      final segment = _segments[i];
      if (segment.startsWith(':')) {
        params[segment.substring(1)] = Uri.decodeComponent(path[i]);
      } else if (segment != path[i]) {
        return null;
      }
    }
    return params;
  }
}

/// A route that matched, with its captured parameters.
final class RouteMatch {
  const RouteMatch(this.route, this.params);

  final MockRoute route;
  final Map<String, String> params;
}

/// The route table. Domains register into one of these.
final class MockRouter {
  final List<MockRoute> _routes = [];

  List<MockRoute> get routes => List.unmodifiable(_routes);

  void get(String pattern, MockHandler handler) => add('GET', pattern, handler);
  void post(String pattern, MockHandler handler) =>
      add('POST', pattern, handler);
  void put(String pattern, MockHandler handler) => add('PUT', pattern, handler);
  void delete(String pattern, MockHandler handler) =>
      add('DELETE', pattern, handler);

  void add(String method, String pattern, MockHandler handler) {
    final route = MockRoute(method.toUpperCase(), pattern, handler);
    if (_routes.any((r) => r.key == route.key)) {
      throw StateError('Route already registered: ${route.key}');
    }
    _routes.add(route);
  }

  /// The match with the most literal segments, so `/v1/characters/search`
  /// beats `/v1/characters/:id`. Null if nothing matches.
  RouteMatch? resolve(String method, String path) {
    final segments = _split(path);
    RouteMatch? best;
    for (final route in _routes) {
      final params = route._match(method.toUpperCase(), segments);
      if (params == null) continue;
      if (best == null || route._literals > best.route._literals) {
        best = RouteMatch(route, params);
      }
    }
    return best;
  }
}
