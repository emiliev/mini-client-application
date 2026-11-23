import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'data/universe.dart';
import 'handlers/characters_handlers.dart';

/// The characters domain: `GET /v1/characters` and `GET /v1/characters/:id`.
/// Documented in `CONTRACT.md`; the same routes are listed in
/// `fixtures/routes.json`, and a test keeps the three in step.
final class CharactersMockDomain implements MockDomain {
  const CharactersMockDomain();

  /// The routes this domain serves, as `"METHOD /pattern"`.
  static const List<String> routeManifest = [
    'GET /v1/characters',
    'GET /v1/characters/:id',
  ];

  @override
  String get name => 'characters';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    final universe = CharacterUniverse(environment.seed, environment.clock);
    router
      ..get('/v1/characters', listCharacters(universe))
      ..get('/v1/characters/:id', characterDetail(universe));
  }

  @override
  Map<String, MockScenario> get scenarios => {
    'characters.empty': const MockScenario(
      'characters.empty',
      overrides: {'GET /v1/characters': emptyPage},
    ),
    'characters.server_error': const MockScenario(
      'characters.server_error',
      rules: [FailureRule('GET', '/v1/characters', FailureKind.http(500))],
    ),
  };
}
