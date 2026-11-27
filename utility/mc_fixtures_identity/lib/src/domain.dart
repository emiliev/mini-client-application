import 'package:mc_fixtures_identity/src/handlers/identity_handlers.dart';
import 'package:mc_fixtures_identity/src/handlers/preferences_handlers.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The identity domain: sign-in, refresh, sign-out, the current user,
/// favourites writes and the user's preferences. Documented in
/// `CONTRACT.md`; the same routes are in `fixtures/routes.json`, and a test
/// keeps the three in step.
final class IdentityMockDomain implements MockDomain {
  /// [seedFavourites] false starts every user with no favourites (the
  /// `identity.empty` set). [withScenarios] false leaves the scenarios out, so
  /// a second set can register next to this one without a name clash.
  const IdentityMockDomain({
    this.seedFavourites = true,
    this.withScenarios = true,
  });

  final bool seedFavourites;
  final bool withScenarios;

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = [
    'POST /v1/auth/sign-in',
    'POST /v1/auth/refresh',
    'POST /v1/auth/sign-out',
    'GET /v1/me',
    'GET /v1/me/favourites/:kind/:id',
    'PUT /v1/me/favourites/:kind/:id',
    'DELETE /v1/me/favourites/:kind/:id',
    'GET /v1/me/preferences',
    'PATCH /v1/me/preferences',
  ];

  /// The routes the `identity.preferences_error` scenario fails.
  static const List<String> preferencesRoutes = [
    'GET /v1/me/preferences',
    'PATCH /v1/me/preferences',
  ];

  @override
  String get name => 'identity';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router
      ..post('/v1/auth/sign-in', signIn())
      ..post('/v1/auth/refresh', refresh)
      ..post('/v1/auth/sign-out', signOut)
      ..get('/v1/me', me(seed: seedFavourites))
      ..get(
        '/v1/me/favourites/:kind/:id',
        favourite('GET', seed: seedFavourites),
      )
      ..put(
        '/v1/me/favourites/:kind/:id',
        favourite('PUT', seed: seedFavourites),
      )
      ..delete(
        '/v1/me/favourites/:kind/:id',
        favourite('DELETE', seed: seedFavourites),
      )
      ..get('/v1/me/preferences', getPreferences)
      ..add('PATCH', '/v1/me/preferences', patchPreferences());
  }

  @override
  Map<String, MockScenario> get scenarios => withScenarios
      ? {
          'identity.expired_token': MockScenario(
            'identity.expired_token',
            overrides: {'POST /v1/auth/sign-in': signIn(expired: true)},
          ),
          'identity.server_error': MockScenario(
            'identity.server_error',
            rules: [
              for (final route in routeManifest)
                FailureRule(
                  route.split(' ').first,
                  route.split(' ').last,
                  const FailureKind.http(500),
                ),
            ],
          ),
          'identity.preferences_error': MockScenario(
            'identity.preferences_error',
            rules: [
              for (final route in preferencesRoutes)
                FailureRule(
                  route.split(' ').first,
                  route.split(' ').last,
                  const FailureKind.http(500),
                ),
            ],
          ),
          'identity.preferences_conflict': MockScenario(
            'identity.preferences_conflict',
            overrides: {
              'PATCH /v1/me/preferences': patchPreferences(conflictOnce: true),
            },
          ),
        }
      : const {};
}

/// The same routes, every one answering `500` (the `identity.server_error`
/// set). It has no scenarios.
final class IdentityServerErrorDomain implements MockDomain {
  const IdentityServerErrorDomain();

  @override
  String get name => 'identity';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    for (final route in IdentityMockDomain.routeManifest) {
      router.add(
        route.split(' ').first,
        route.split(' ').last,
        (request, context) => MockResponse.error(
          500,
          'server_error',
          'The identity service is failing',
        ),
      );
    }
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}
