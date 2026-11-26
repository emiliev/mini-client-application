import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// How `fail` makes a route fail. Maps onto `mc_mocked_backend`'s kinds.
enum BackendFailure {
  serverError,
  timeout,
  offline,
  notFound,
  unauthorized,
  malformed;

  FailureKind get kind => switch (this) {
    serverError => const FailureKind.http(500),
    timeout => const FailureKind.timeout(),
    offline => const FailureKind.offline(),
    notFound => const FailureKind.notFound(),
    unauthorized => const FailureKind.unauthorized(),
    malformed => const FailureKind.malformed(),
  };
}

/// One request the app made, in order.
final class RecordedRequest {
  const RecordedRequest({
    required this.method,
    required this.path,
    this.query = const {},
    this.headers = const {},
    this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;

  /// The headers as the request left the app: after every interceptor of
  /// the `Dio` ran (the auth interceptor's bearer included), as strings.
  final Map<String, String> headers;
  final Object? body;

  /// `GET /v1/characters`.
  String get routeKey => '$method $path';

  @override
  String toString() => query.isEmpty
      ? routeKey
      : '$routeKey?${Uri(queryParameters: query).query}';
}

/// True when [request] matches [route] (`METHOD /path[?query subset]`).
bool matchesRequest(RecordedRequest request, String route) =>
    _Route.parse(route).matches(request.method, request.path, request.query);

class _Route {
  _Route(this.method, this.path, this.query);

  factory _Route.parse(String route) {
    final space = route.indexOf(' ');
    if (space <= 0) {
      throw ArgumentError.value(
        route,
        'route',
        'Expected "<METHOD> <path>[?<query>]", e.g. '
            '"GET /v1/characters?offset=20".',
      );
    }
    final method = route.substring(0, space).toUpperCase();
    final rest = route.substring(space + 1).trim();
    final q = rest.indexOf('?');
    final path = q < 0 ? rest : rest.substring(0, q);
    final query = q < 0
        ? const <String, String>{}
        : Uri.splitQueryString(rest.substring(q + 1));
    return _Route(method, path, query);
  }

  final String method;
  final String path;
  final Map<String, String> query;

  late final FailureRule _rule = FailureRule(
    method,
    path,
    const FailureKind.timeout(),
  );

  bool matches(String method, String path, Map<String, String> query) =>
      _rule.matches(MockRequest(method: method, path: path)) &&
      queryMatches(query);

  bool queryMatches(Map<String, String> actual) =>
      query.entries.every((e) => actual[e.key] == e.value);

  bool sameAs(_Route other) =>
      method == other.method &&
      path == other.path &&
      query.length == other.query.length &&
      query.entries.every((e) => other.query[e.key] == e.value);
}

/// Mirrors one injected failure so the adapter knows which requests the
/// harness's own rules answer (those are not "unmatched"). Counting follows
/// the engine: only matching requests count, up to the first rule that fires.
class _FailRule {
  _FailRule(this.route, this.times);

  final _Route route;
  final int times;
  int calls = 0;

  /// Cleared by `McBackendHarness.recover`: the engine-side rule stops
  /// matching, and this mirror is dropped.
  bool live = true;

  bool get fires => times < 0 || calls <= times;
}

typedef _Hold = ({_Route route, Completer<void> gate});

final Map<String, MockDomain Function()> _fixtureSets = {};

/// The named fixture sets a test can switch on with
/// [McBackendHarness.useFixtureSet]. Register them once (in `main()` or a
/// top-level initialiser); which ones are active is per-test state.
abstract final class McFixtureSets {
  /// Registers [name] (for example `characters.paged_45`). [build] makes a
  /// fresh domain per use.
  static void register(String name, MockDomain Function() build) =>
      _fixtureSets[name] = build;

  static Iterable<String> get names => _fixtureSets.keys;
}

/// The test double for the network: `mc_mocked_backend` behind the same Dio
/// adapter seam the app uses (TD-01). Strict: a request no route answers is
/// recorded as unmatched and fails the test in [verify].
final class McBackendHarness {
  McBackendHarness({int seed = 42}) : backend = MockBackend(seed: seed) {
    adapter = _HarnessAdapter(this);
  }

  /// The engine, for tests that need its diagnostics.
  final MockBackend backend;

  /// The `HttpClientAdapter` the root `Dio` is built on.
  late final HttpClientAdapter adapter;

  final List<RecordedRequest> _requests = [];
  final List<String> _unmatched = [];
  final List<_Hold> _holds = [];
  final List<_FailRule> _failRules = [];
  final Set<String> _active = {};

  /// Every request so far (method, path, query, body), in order.
  List<RecordedRequest> get requests => List.unmodifiable(_requests);

  /// The names of the fixture sets switched on.
  Set<String> get activeFixtureSets => Set.unmodifiable(_active);

  /// True while some hold has not been released.
  bool get hasHolds => _holds.isNotEmpty;

  /// `METHOD path` of each request that no route answered.
  List<String> get unmatched => List.unmodifiable(_unmatched);

  /// Switches on the fixture set [name] registered with [McFixtureSets].
  /// Using a set twice is a no-op.
  void useFixtureSet(String name) {
    final build = _fixtureSets[name];
    if (build == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Unknown fixture set. Registered: ${_fixtureSets.keys.toList()..sort()}',
      );
    }
    if (_active.add(name)) {
      useDomain(build());
    }
  }

  /// Registers the routes of [domain] directly.
  /// Its scenarios become selectable with `backend.useScenario`.
  void useDomain(MockDomain domain) => backend.addDomain(domain);

  /// Makes [route] (`GET /v1/characters?offset=20`) fail with [failure] for
  /// the next [times] matching requests, or every time when [times] is -1.
  /// A retry beyond [times] gets the normal answer.
  void fail(String route, BackendFailure failure, {int times = -1}) {
    final parsed = _Route.parse(route);
    final mirror = _FailRule(parsed, times);
    _failRules.add(mirror);
    backend.addFailure(
      FailureRule(
        parsed.method,
        parsed.path,
        failure.kind,
        times < 0 ? FailureTrigger.always : FailureTrigger.times(times),
        // A recovered rule never matches again (the engine only counts
        // matching requests, so it is inert).
        (query) => mirror.live && parsed.queryMatches(query),
      ),
    );
  }

  /// The backend recovers: every failure injected with [fail] stops, on the
  /// engine and in the harness's own bookkeeping (so a later request to a
  /// route no fixture set answers is reported as unmatched again), and the
  /// active scenario ends. Routes, the engine's store, latency, counters and
  /// [requests] are kept, unlike `backend.reset()`.
  void recover() {
    for (final rule in _failRules) {
      rule.live = false;
    }
    _failRules.clear();
    backend.useScenario(null);
  }

  /// Makes matching requests pend until [release], so the loading state can
  /// be observed deterministically. No timers are involved.
  void hold(String route) =>
      _holds.add((route: _Route.parse(route), gate: Completer<void>()));

  /// Lets the requests held on [route], and later ones, through.
  Future<void> release(String route) async {
    final parsed = _Route.parse(route);
    final released = _holds.where((h) => h.route.sameAs(parsed)).toList();
    if (released.isEmpty) {
      throw StateError('No hold on "$route" to release.');
    }
    for (final hold in released) {
      _holds.remove(hold);
      hold.gate.complete();
    }
  }

  void _checkMatched(String method, String path, Map<String, String> query) {
    var failed = false;
    for (final rule in _failRules) {
      if (!failed && rule.route.matches(method, path, query)) {
        rule.calls++;
        failed = rule.fires;
      }
    }
    if (failed) {
      return;
    }
    final RouteMatch? match;
    try {
      match = backend.router.resolve(method, path);
    } on FormatException {
      return; // The engine answers 400.
    }
    if (match == null) {
      _unmatched.add('$method $path');
    }
  }

  /// Fails the test on a request no route answered, or on a hold that was
  /// never released.
  void verify() {
    if (_unmatched.isNotEmpty) {
      throw TestFailure(
        '${_unmatched.map((u) => 'Unmatched request $u').join('\n')}\n'
        'No route answers it. Switch on a fixture set that has it '
        '(active: ${_active.isEmpty ? 'none' : _active.join(', ')}) '
        'or register a domain with useDomain.',
      );
    }
    if (_holds.isNotEmpty) {
      throw TestFailure(
        _holds
            .map(
              (h) =>
                  'Held request never released: ${h.route.method} '
                  '${h.route.path}',
            )
            .join('\n'),
      );
    }
  }

  /// Returns and forgets the unmatched requests. For tests of the harness
  /// itself, which provoke them on purpose.
  List<String> takeUnmatched() {
    final taken = List.of(_unmatched);
    _unmatched.clear();
    return taken;
  }

  /// Forgets the holds without releasing them (the harness's own tests).
  void clearHolds() => _holds.clear();
}

/// Waits for [gate]; a cancelled request stops waiting, as on a network.
Future<void> _awaitGate(
  Completer<void> gate,
  Future<void>? cancel,
  RequestOptions options,
) async {
  final released = Completer<bool>();
  unawaited(
    gate.future.then((_) {
      if (!released.isCompleted) {
        released.complete(true);
      }
    }),
  );
  unawaited(
    cancel?.then((_) {
          if (!released.isCompleted) {
            released.complete(false);
          }
        }, onError: (Object _) {}) ??
        Future<void>.value(),
  );
  if (!await released.future) {
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: 'Cancelled while held by the test harness',
    );
  }
}

class _HarnessAdapter implements HttpClientAdapter {
  _HarnessAdapter(this._harness);

  final McBackendHarness _harness;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final method = options.method.toUpperCase();
    var path = options.uri.path;
    var query = const <String, String>{};
    var malformed = false;
    try {
      query = options.uri.queryParameters;
    } on FormatException {
      // Forwarded: the engine answers 400, as a server would.
      malformed = true;
    }
    _harness._requests.add(
      RecordedRequest(
        method: method,
        path: path,
        query: query,
        headers: {
          for (final e in options.headers.entries) e.key: '${e.value}',
        },
        body: options.data,
      ),
    );
    if (!malformed) {
      _harness._checkMatched(method, path, query);
    }
    for (final hold in List.of(_harness._holds)) {
      if (hold.route.matches(method, path, query)) {
        await _awaitGate(hold.gate, cancelFuture, options);
      }
    }
    return _harness.backend.adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
