import 'package:mc_fixtures_library/src/handlers/library_handlers.dart'
    as handlers;
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The routes of the library domain, as `"METHOD /pattern"`. Documented in
/// `CONTRACT.md`; the same routes are listed in `fixtures/routes.json`, and a
/// test keeps the three in step.
const List<String> libraryRouteManifest = [
  'GET /v1/me/lists',
  'GET /v1/me/lists/:id',
  'POST /v1/me/lists',
  'PUT /v1/me/lists/:id',
  'PUT /v1/me/lists/:id/items',
  'DELETE /v1/me/lists/:id',
];

Map<String, MockHandler> _handlers({required bool seed}) => {
  'GET /v1/me/lists': handlers.listLists(seed: seed),
  'GET /v1/me/lists/:id': handlers.getList(seed: seed),
  'POST /v1/me/lists': handlers.createList(seed: seed),
  'PUT /v1/me/lists/:id': handlers.updateList(seed: seed),
  'PUT /v1/me/lists/:id/items': handlers.replaceItems(seed: seed),
  'DELETE /v1/me/lists/:id': handlers.deleteList(seed: seed),
};

void _register(MockRouter router, Map<String, MockHandler> byRoute) {
  for (final MapEntry(:key, :value) in byRoute.entries) {
    final [method, pattern] = key.split(' ');
    router.add(method, pattern, value);
  }
}

/// The library domain: the signed-in user's reading lists, read and written
/// in the backend's store (kept until `reset()`). Every route needs a bearer
/// from `mc_fixtures_identity`.
final class LibraryMockDomain implements MockDomain {
  const LibraryMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = libraryRouteManifest;

  @override
  String get name => 'library';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, _handlers(seed: true));

  @override
  Map<String, MockScenario> get scenarios => {
    'library.empty': MockScenario(
      'library.empty',
      overrides: _handlers(seed: false),
    ),
    'library.server_error': MockScenario(
      'library.server_error',
      rules: [
        for (final route in libraryRouteManifest)
          FailureRule(
            route.split(' ').first,
            route.split(' ').last,
            const FailureKind.http(500),
          ),
      ],
    ),
  };
}

/// The same routes with no seeded lists (the `library.empty` set). Auth and
/// validation are unchanged. It has no scenarios.
final class EmptyLibraryDomain implements MockDomain {
  const EmptyLibraryDomain();

  @override
  String get name => 'library';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(
        router,
        _handlers(seed: false),
      );

  @override
  Map<String, MockScenario> get scenarios => const {};
}

/// The same routes, each answering `500` (the `library.server_error` set).
/// It has no scenarios.
final class FailingLibraryDomain implements MockDomain {
  const FailingLibraryDomain();

  @override
  String get name => 'library';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) =>
      _register(router, {
        for (final route in libraryRouteManifest) route: handlers.serverError,
      });

  @override
  Map<String, MockScenario> get scenarios => const {};
}
