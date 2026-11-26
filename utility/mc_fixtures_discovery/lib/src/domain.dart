import 'package:mc_fixtures_discovery/src/handlers/search_handlers.dart'
    as handlers;
import 'package:mc_fixtures_discovery/src/search/index.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the discovery domain, as `"METHOD /pattern"`. Documented in
/// `CONTRACT.md`; the same routes are listed in `fixtures/routes.json`, and a
/// test keeps the three in step.
const List<String> discoveryRouteManifest = [
  'GET /v1/search',
  'GET /v1/search/suggestions',
];

void _registerRoutes(MockRouter router, SearchIndex index) {
  router
    ..get('/v1/search', handlers.search(index))
    ..get('/v1/search/suggestions', handlers.suggestions(index));
}

/// The discovery domain: global search over the characters and comics
/// universes of the backend's seed.
final class DiscoveryMockDomain implements MockDomain {
  const DiscoveryMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = discoveryRouteManifest;

  @override
  String get name => 'discovery';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _registerRoutes(
        router,
        SearchIndex.fromUniverses(environment.seed, environment.clock),
      );

  @override
  Map<String, MockScenario> get scenarios => {
    'discovery.empty': MockScenario(
      'discovery.empty',
      overrides: {
        'GET /v1/search': handlers.search(SearchIndex.empty),
        'GET /v1/search/suggestions': handlers.suggestions(SearchIndex.empty),
      },
    ),
    'discovery.server_error': const MockScenario(
      'discovery.server_error',
      rules: [
        FailureRule('GET', '/v1/search', FailureKind.http(500)),
        FailureRule('GET', '/v1/search/suggestions', FailureKind.http(500)),
      ],
    ),
  };
}

/// The discovery routes over a catalogue the caller builds, with the same
/// validation, ranking and envelope as [DiscoveryMockDomain]. For tests that
/// need exact titles (duplicates, ties). It has no scenarios.
final class IndexedDiscoveryDomain implements MockDomain {
  const IndexedDiscoveryDomain(this.index);

  final SearchIndex index;

  @override
  String get name => 'discovery';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _registerRoutes(router, index);

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The discovery routes over an index with nothing in it: the same
/// validation, every group `total: 0`, no suggestions. It has no scenarios.
final class EmptyDiscoveryDomain implements MockDomain {
  const EmptyDiscoveryDomain();

  @override
  String get name => 'discovery';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _registerRoutes(router, SearchIndex.empty);

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The discovery routes, each answering `500`. It has no scenarios.
final class FailingDiscoveryDomain implements MockDomain {
  const FailingDiscoveryDomain();

  @override
  String get name => 'discovery';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      ..get('/v1/search', handlers.serverError)
      ..get('/v1/search/suggestions', handlers.serverError);
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}
