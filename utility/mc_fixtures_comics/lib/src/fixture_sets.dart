import 'package:mc_fixtures_comics/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const ComicsMockDomain();
MockDomain _paged45() => const SyntheticComicsDomain(45);
MockDomain _empty() => const SyntheticComicsDomain(0);
MockDomain _serverError() => const FailingComicsDomain();

/// The named fixture sets of this domain (plan 05 §3.4). A test registers
/// them once (`comicsFixtureSets.forEach(McFixtureSets.register)`) and a
/// scenario switches one on with `the backend serves {'<name>'}`. Facts the
/// tests rely on are in CONTRACT.md, "Fixture sets".
const Map<String, MockDomain Function()> comicsFixtureSets = {
  'comics.default': _default,
  'comics.paged_45': _paged45,
  'comics.empty': _empty,
  'comics.server_error': _serverError,
};
