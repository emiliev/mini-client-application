import 'package:mc_fixtures_characters/src/data/universe.dart';
import 'package:mc_fixtures_characters/src/domain.dart';
import 'package:mc_fixtures_characters/src/handlers/characters_handlers.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// The characters routes over a synthetic cast of [count] (`Hero 01` ...),
/// with the same paging, validation and envelope as [CharactersMockDomain].
/// It has no scenarios, so it never clashes with that domain's names.
final class SyntheticCharactersDomain implements MockDomain {
  const SyntheticCharactersDomain(this.count);

  final int count;

  @override
  String get name => 'characters';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    final universe = CharacterUniverse.synthetic(count, environment.clock);
    router
      ..get('/v1/characters', listCharacters(universe))
      ..get('/v1/characters/:id', characterDetail(universe));
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

MockDomain _default() => const CharactersMockDomain();
MockDomain _paged45() => const SyntheticCharactersDomain(45);
MockDomain _empty() => const SyntheticCharactersDomain(0);

/// The named fixture sets of this domain (plan 05 §3.4). A test registers
/// them once (`charactersFixtureSets.forEach(McFixtureSets.register)`) and a
/// scenario switches one on with `the backend serves {'<name>'}`. Facts the
/// tests rely on are in CONTRACT.md, "Fixture sets".
const Map<String, MockDomain Function()> charactersFixtureSets = {
  'characters.default': _default,
  'characters.paged_45': _paged45,
  'characters.empty': _empty,
};
