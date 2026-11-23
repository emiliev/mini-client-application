import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'failure_rule.dart';
import 'latency.dart';
import 'mock_http.dart';
import 'router.dart';
import 'seeded_random.dart';
import 'traffic.dart';

/// A named bundle of failures and handler overrides, selected by config, a BDD
/// step or the developer menu (plan 01 §5 "Scenarios").
final class MockScenario {
  const MockScenario(
    this.name, {
    this.rules = const [],
    this.overrides = const {},
  });

  final String name;
  final List<FailureRule> rules;

  /// Replacement handlers keyed by `"METHOD /path/pattern"`.
  final Map<String, MockHandler> overrides;
}

/// A domain package (`mc_fixtures_<domain>`) registers its routes here. The
/// engine itself holds no data (R3).
abstract interface class MockDomain {
  String get name;

  void register(MockRouter router, MockDomainEnvironment environment);

  Map<String, MockScenario> get scenarios;
}

/// What a domain may read while registering.
final class MockDomainEnvironment {
  const MockDomainEnvironment({required this.seed, required this.clock});

  final int seed;
  final DateTime clock;
}

/// The default fixed clock, `2026-01-01T00:00Z`.
final DateTime defaultMockClock = DateTime.utc(2026);

final class _ActiveRule {
  _ActiveRule(this.rule);

  final FailureRule rule;
  int calls = 0;
}

/// A deterministic, in-process backend that behaves like a network one:
/// routing, seeded latency, injectable failures and a traffic log.
///
/// Wire it with [createDio] or by setting `dio.httpClientAdapter = adapter`.
/// One instance per test; [reset] clears all mutable state.
final class MockBackend {
  MockBackend({
    this.seed = 42,
    LatencyProfile latency = LatencyProfile.none,
    List<MockDomain> domains = const [],
    List<FailureRule> failures = const [],
    DateTime? clock,
    this.trafficCapacity = 500,
    this.timeout = const Duration(seconds: 30),
  }) : clock = clock ?? defaultMockClock,
       _initialLatency = latency,
       _latency = latency,
       _initialFailures = List.unmodifiable(failures),
       _domains = List.unmodifiable(domains),
       _root = SplitMix64(seed) {
    final environment = MockDomainEnvironment(seed: seed, clock: this.clock);
    for (final domain in _domains) {
      domain.register(router, environment);
      for (final scenario in domain.scenarios.values) {
        if (_scenarios.containsKey(scenario.name)) {
          throw StateError('Duplicate scenario: ${scenario.name}');
        }
        _scenarios[scenario.name] = scenario;
      }
    }
    _resetRules();
  }

  final int seed;
  final DateTime clock;
  final int trafficCapacity;

  /// The duration reported by the `connectionTimeout` exception.
  final Duration timeout;

  final MockRouter router = MockRouter();

  final LatencyProfile _initialLatency;
  final List<FailureRule> _initialFailures;
  final List<MockDomain> _domains;
  final SplitMix64 _root;
  final Map<String, MockScenario> _scenarios = {};
  final Map<String, Object?> _store = {};
  final Queue<TrafficEntry> _traffic = Queue();
  final StreamController<TrafficEntry> _trafficController =
      StreamController.broadcast(sync: true);

  LatencyProfile _latency;
  MockScenario? _scenario;
  final List<_ActiveRule> _configured = [];
  final List<_ActiveRule> _injected = [];
  int _requests = 0;

  late final MockBackendAdapter adapter = MockBackendAdapter(this);

  /// A [Dio] on this backend. The base URL is never contacted.
  Dio createDio({String baseUrl = 'https://mock.mini-client.invalid'}) =>
      Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;

  // --- Diagnostics (the `NetworkDiagnostics` surface) -----------------------

  LatencyProfile get latency => _latency;

  void setLatency(LatencyProfile profile) => _latency = profile;

  /// Fails the next matching request once.
  void failNext(String method, String path, FailureKind kind) => _injected.add(
    _ActiveRule(FailureRule(method, path, kind, FailureTrigger.once)),
  );

  void addFailure(FailureRule rule) => _injected.add(_ActiveRule(rule));

  /// Selects a scenario by name, or none for null.
  void useScenario(String? name) {
    if (name != null && !_scenarios.containsKey(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'Unknown scenario. Known: ${_scenarios.keys.toList()..sort()}',
      );
    }
    _scenario = name == null ? null : _scenarios[name];
    _resetRules();
  }

  Iterable<String> get scenarioNames => _scenarios.keys;

  /// Every request, live.
  Stream<TrafficEntry> get traffic => _trafficController.stream;

  /// The last [trafficCapacity] requests, oldest first.
  List<TrafficEntry> get recentTraffic => List.unmodifiable(_traffic);

  /// Clears the store, rules, scenario, latency, counters and traffic.
  void reset() {
    _store.clear();
    _traffic.clear();
    _injected.clear();
    _scenario = null;
    _latency = _initialLatency;
    _requests = 0;
    _resetRules();
  }

  void _resetRules() {
    _configured
      ..clear()
      ..addAll(
        [
          ...(_scenario?.rules ?? const <FailureRule>[]),
          ..._initialFailures,
        ].map(_ActiveRule.new),
      );
  }

  /// The delay request number [index] (0-based) gets under the current
  /// profile. A pure function of the seed, so tests can assert on it.
  Duration latencyForRequest(int index) =>
      _latency.delayFor(_root.fork('latency').fork('$index'));

  // --- Pipeline: failure rules -> route -> latency -> handler ---------------

  Future<ResponseBody> handle(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    final index = _requests++;
    final request = await _toRequest(options, requestStream);
    var delay = latencyForRequest(index);

    FailureKind? failure;
    var ruleIndex = 0;
    for (final active in [..._configured, ..._injected]) {
      final i = ruleIndex++;
      if (!active.rule.matches(request)) continue;
      active.calls++;
      final rng = _root.fork('failure').fork('$i:${active.calls}');
      if (failure == null && active.rule.trigger.fires(active.calls, rng)) {
        failure = active.rule.kind;
      }
    }
    if (failure is SlowFailure) delay += failure.delay;

    if (delay > Duration.zero) await Future<void>.delayed(delay);

    TrafficEntry entry(int? status, [String? error]) => TrafficEntry(
      method: request.method,
      path: request.path,
      status: status,
      duration: delay,
      error: error,
    );

    switch (failure) {
      case TimeoutFailure():
        final e = DioException.connectionTimeout(
          timeout: timeout,
          requestOptions: options,
        );
        _record(entry(null, e.type.name));
        throw e;
      case OfflineFailure():
        final e = DioException.connectionError(
          requestOptions: options,
          reason: 'Mock backend is offline',
        );
        _record(entry(null, e.type.name));
        throw e;
      case HttpFailure(:final status):
        return _respond(
          MockResponse.error(
            status,
            'injected_failure',
            'Injected HTTP $status for ${request.routeKey}',
          ),
          entry,
        );
      case MalformedFailure():
        _record(entry(200));
        return _body('{"results": [', 200);
      case SlowFailure() || null:
        break;
    }

    final match = router.resolve(request.method, request.path);
    if (match == null) {
      return _respond(
        MockResponse.error(
          404,
          'not_found',
          'No mock route for ${request.method} ${request.path}',
          extra: {'path': request.path},
        ),
        entry,
      );
    }

    final handler =
        _scenario?.overrides[match.route.key] ?? match.route.handler;
    final MockResponse response;
    try {
      response = await handler(
        request,
        MockContext(
          seed: seed,
          clock: clock,
          params: match.params,
          store: _store,
        ),
      );
    } on Object catch (e) {
      return _respond(
        MockResponse.error(
          500,
          'handler_error',
          'Handler for ${match.route.key} threw: $e',
        ),
        entry,
      );
    }
    return _respond(response, entry);
  }

  ResponseBody _respond(
    MockResponse response,
    TrafficEntry Function(int? status, [String? error]) entry,
  ) {
    _record(entry(response.status));
    return _body(response.encode(), response.status);
  }

  ResponseBody _body(String json, int status) => ResponseBody.fromString(
    json,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );

  void _record(TrafficEntry entry) {
    _traffic.add(entry);
    while (_traffic.length > trafficCapacity) {
      _traffic.removeFirst();
    }
    _trafficController.add(entry);
  }

  Future<MockRequest> _toRequest(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      final text = utf8.decode(bytes);
      if (text.isNotEmpty) {
        try {
          body = jsonDecode(text);
        } on FormatException {
          body = text;
        }
      }
    } else {
      body = options.data;
    }
    final uri = options.uri;
    return MockRequest(
      method: options.method.toUpperCase(),
      path: uri.path,
      query: {
        for (final e in uri.queryParametersAll.entries) e.key: e.value.last,
      },
      headers: {
        for (final e in options.headers.entries)
          e.key.toLowerCase(): e.value.toString(),
      },
      body: body,
    );
  }
}

/// The Dio transport. Timeouts and offline throw the same `DioException`
/// types a real network gives, so `mc_api_errors` is exercised for real.
final class MockBackendAdapter implements HttpClientAdapter {
  MockBackendAdapter(this._backend);

  final MockBackend _backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _backend.handle(options, requestStream);

  @override
  void close({bool force = false}) {}
}
