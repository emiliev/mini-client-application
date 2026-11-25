import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:mc_mocked_backend/src/failure_rule.dart';
import 'package:mc_mocked_backend/src/latency.dart';
import 'package:mc_mocked_backend/src/mock_http.dart';
import 'package:mc_mocked_backend/src/router.dart';
import 'package:mc_mocked_backend/src/seeded_random.dart';
import 'package:mc_mocked_backend/src/traffic.dart';

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
    for (final domain in _domains) {
      _register(domain);
    }
    _resetRules();
  }

  final int seed;
  final DateTime clock;
  final int trafficCapacity;

  /// The duration reported by the `connectionTimeout` exception.
  final Duration timeout;

  final MockRouter router = MockRouter();

  void _register(MockDomain domain) {
    domain.register(router, MockDomainEnvironment(seed: seed, clock: clock));
    for (final scenario in domain.scenarios.values) {
      if (_scenarios.containsKey(scenario.name)) {
        throw StateError('Duplicate scenario: ${scenario.name}');
      }
      _scenarios[scenario.name] = scenario;
    }
  }

  /// Registers [domain]'s routes and scenarios after construction (the test
  /// harness switches fixture sets on per test).
  void addDomain(MockDomain domain) {
    _register(domain);
  }

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
  Dio createDio({String baseUrl = 'https://mock.mini-client.invalid/'}) =>
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

  // --- Pipeline: failure rules -> latency -> route -> handler ---------------

  /// The first rule (injected ones first) that matches [request] and fires.
  /// Only rules that match are counted, and rules after the winner are not
  /// touched, so a `once` rule is consumed only by the request it fails.
  FailureKind? _pickFailure(MockRequest request) {
    final rules = [..._injected, ..._configured];
    for (var i = 0; i < rules.length; i++) {
      final active = rules[i];
      if (!active.rule.matches(request)) {
        continue;
      }
      final call = active.calls + 1;
      final rng = _root.fork('failure').fork('$i:$call');
      active.calls = call;
      if (active.rule.trigger.fires(call, rng)) {
        return active.rule.kind;
      }
    }
    return null;
  }

  Future<ResponseBody> handle(
    RequestOptions options,
    Stream<Uint8List>? requestStream, [
    Future<void>? cancelFuture,
  ]) async {
    final index = _requests++;
    String? badRequest;
    MockRequest request;
    try {
      request = await _toRequest(options, requestStream);
    } on FormatException catch (e) {
      badRequest = 'Malformed request URL: ${e.message}';
      request = MockRequest(
        method: options.method.toUpperCase(),
        path: options.uri.path,
      );
    }
    var delay = latencyForRequest(index);

    final failure = badRequest == null ? _pickFailure(request) : null;
    if (failure is SlowFailure) {
      delay += failure.delay;
    }

    TrafficEntry entry(int? status, Duration duration, [String? error]) =>
        TrafficEntry(
          method: request.method,
          path: request.path,
          status: status,
          duration: duration,
          error: error,
        );

    // A delay beyond the request's own timeouts is that timeout, after
    // waiting for it, as on a real network.
    final connect = options.connectTimeout;
    final receive = options.receiveTimeout;
    DioException? timedOut;
    var wait = delay;
    if (connect != null && connect > Duration.zero && delay > connect) {
      wait = connect;
      timedOut = DioException.connectionTimeout(
        timeout: connect,
        requestOptions: options,
      );
    }
    if (receive != null &&
        receive > Duration.zero &&
        delay > receive &&
        (timedOut == null || receive < wait)) {
      wait = receive;
      timedOut = DioException.receiveTimeout(
        timeout: receive,
        requestOptions: options,
      );
    }

    if (wait > Duration.zero && !await _sleep(wait, cancelFuture)) {
      _record(entry(null, Duration.zero, 'cancel'));
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'Cancelled while waiting for the mock backend',
      );
    }
    if (timedOut != null) {
      _record(entry(null, wait, timedOut.type.name));
      throw timedOut;
    }

    ResponseBody respond(MockResponse response) {
      _record(entry(response.status, delay));
      return _body(response.encode(), response.status);
    }

    switch (failure) {
      case TimeoutFailure():
        final e = DioException.connectionTimeout(
          timeout: connect ?? timeout,
          requestOptions: options,
        );
        _record(entry(null, delay, e.type.name));
        throw e;
      case OfflineFailure():
        final e = DioException.connectionError(
          requestOptions: options,
          reason: 'Mock backend is offline',
        );
        _record(entry(null, delay, e.type.name));
        throw e;
      case HttpFailure(:final status):
        return respond(
          MockResponse.error(
            status,
            'injected_failure',
            'Injected HTTP $status for ${request.routeKey}',
          ),
        );
      case MalformedFailure():
        _record(entry(200, delay));
        return _body('{"results": [', 200);
      case SlowFailure() || null:
        break;
    }

    if (badRequest != null) {
      return respond(MockResponse.error(400, 'bad_request', badRequest));
    }
    final RouteMatch? match;
    try {
      match = router.resolve(request.method, request.path);
    } on FormatException catch (e) {
      return respond(
        MockResponse.error(
          400,
          'bad_request',
          'Malformed path ${request.path}: ${e.message}',
          extra: {'path': request.path},
        ),
      );
    }
    if (match == null) {
      return respond(
        MockResponse.error(
          404,
          'not_found',
          'No mock route for ${request.method} ${request.path}',
          extra: {'path': request.path},
        ),
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
      return respond(
        MockResponse.error(
          500,
          'handler_error',
          'Handler for ${match.route.key} threw: $e',
        ),
      );
    }
    return respond(response);
  }

  /// Waits [d]; false if [cancel] completes first (the timer is dropped).
  Future<bool> _sleep(Duration d, Future<void>? cancel) {
    final done = Completer<bool>();
    final timer = Timer(d, () {
      if (!done.isCompleted) {
        done.complete(true);
      }
    });
    cancel?.then((_) {
      if (!done.isCompleted) {
        timer.cancel();
        done.complete(false);
      }
    }, onError: (_) {});
    return done.future;
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

  /// Throws [FormatException] for a URL that cannot be decoded.
  Future<MockRequest> _toRequest(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
      final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
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
          e.key.toLowerCase(): e.value is Iterable
              ? (e.value as Iterable).join(', ')
              : e.value.toString(),
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
  ) => _backend.handle(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) {}
}
