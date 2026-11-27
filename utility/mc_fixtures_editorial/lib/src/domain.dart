import 'package:mc_fixtures_editorial/src/handlers/trivia_handlers.dart'
    as handlers;
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the trivia domain, as `"METHOD /pattern"`. Documented in
/// `CONTRACT.md`; the same routes are listed in `fixtures/routes.json`, and a
/// test keeps the three in step.
const List<String> triviaRouteManifest = [
  'GET /v1/trivia/categories',
  'GET /v1/trivia/rounds',
  'POST /v1/me/trivia/results',
  'GET /v1/me/trivia/best',
];

/// How long the `trivia.slow` scenario delays every answer.
const Duration triviaSlowDelay = Duration(seconds: 2);

Map<String, MockHandler> _handlers({required bool empty}) => {
  'GET /v1/trivia/categories': handlers.listCategories(empty: empty),
  'GET /v1/trivia/rounds': handlers.getRound(empty: empty),
  'POST /v1/me/trivia/results': handlers.postResult(empty: empty),
  'GET /v1/me/trivia/best': handlers.getBest(empty: empty),
};

void _register(MockRouter router, Map<String, MockHandler> byRoute) {
  for (final MapEntry(:key, :value) in byRoute.entries) {
    final [method, pattern] = key.split(' ');
    router.add(method, pattern, value);
  }
}

List<FailureRule> _rules(FailureKind kind) => [
  for (final route in triviaRouteManifest)
    FailureRule(route.split(' ').first, route.split(' ').last, kind),
];

/// The trivia domain: timed multiple-choice rounds about the comics and
/// characters of the backend's seed, scored on the server, with each user's
/// best scores kept in the backend's store (until `reset()`).
final class TriviaMockDomain implements MockDomain {
  const TriviaMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = triviaRouteManifest;

  @override
  String get name => 'trivia';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, _handlers(empty: false));

  @override
  Map<String, MockScenario> get scenarios => {
    'trivia.empty': MockScenario(
      'trivia.empty',
      overrides: _handlers(empty: true),
    ),
    'trivia.server_error': MockScenario(
      'trivia.server_error',
      rules: _rules(const FailureKind.http(500)),
    ),
    'trivia.slow': MockScenario(
      'trivia.slow',
      rules: _rules(const FailureKind.slow(triviaSlowDelay)),
    ),
  };
}

/// The same routes with no categories, no questions and no stored scores
/// (the `trivia.empty` set). Auth and validation are unchanged. It has no
/// scenarios.
final class EmptyTriviaDomain implements MockDomain {
  const EmptyTriviaDomain();

  @override
  String get name => 'trivia';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, _handlers(empty: true));

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The same routes, each answering `500` (the `trivia.server_error` set). It
/// has no scenarios.
final class FailingTriviaDomain implements MockDomain {
  const FailingTriviaDomain();

  @override
  String get name => 'trivia';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, {
        for (final route in triviaRouteManifest) route: handlers.serverError,
      });

  @override
  Map<String, MockScenario> get scenarios => const {};
}
