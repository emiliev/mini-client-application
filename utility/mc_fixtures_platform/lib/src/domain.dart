import 'package:mc_fixtures_platform/src/handlers/flags_handlers.dart'
    as handlers;
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the platform domain (flags slice), as `"METHOD /pattern"`.
/// Documented in `CONTRACT.md`; the same routes are listed in
/// `fixtures/routes.json`, and a test keeps the three in step.
const List<String> platformRouteManifest = ['GET /v1/flags'];

void _register(MockRouter router, MockHandler flags) =>
    router.add('GET', '/v1/flags', flags);

/// The platform domain: remote feature flags and experiments, with seeded
/// users targeted differently from anonymous. No route needs a bearer.
final class PlatformMockDomain implements MockDomain {
  const PlatformMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = platformRouteManifest;

  @override
  String get name => 'platform';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, handlers.defaultFlags);

  @override
  Map<String, MockScenario> get scenarios => const {
    'platform.empty': MockScenario(
      'platform.empty',
      overrides: {'GET /v1/flags': handlers.emptyFlags},
    ),
    'platform.flags_malformed': MockScenario(
      'platform.flags_malformed',
      overrides: {'GET /v1/flags': handlers.malformedFlags},
    ),
    'platform.server_error': MockScenario(
      'platform.server_error',
      rules: [FailureRule('GET', '/v1/flags', FailureKind.http(500))],
    ),
  };
}

/// The same route with no flags and no experiments (the `platform.empty`
/// set). It has no scenarios.
final class EmptyPlatformDomain implements MockDomain {
  const EmptyPlatformDomain();

  @override
  String get name => 'platform';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, handlers.emptyFlags);

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The same route with wrong-typed values (the `platform.flags_malformed`
/// set). It has no scenarios.
final class MalformedFlagsPlatformDomain implements MockDomain {
  const MalformedFlagsPlatformDomain();

  @override
  String get name => 'platform';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, handlers.malformedFlags);

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The same route answering `500` (the `platform.server_error` set). It has
/// no scenarios.
final class FailingPlatformDomain implements MockDomain {
  const FailingPlatformDomain();

  @override
  String get name => 'platform';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, handlers.serverError);

  @override
  Map<String, MockScenario> get scenarios => const {};
}
