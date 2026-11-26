import 'package:mc_fixtures_identity/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const IdentityMockDomain();
MockDomain _empty() =>
    const IdentityMockDomain(seedFavourites: false, withScenarios: false);
MockDomain _serverError() => const IdentityServerErrorDomain();

/// The named fixture sets of this domain (plan 05 §3.4), switched on per test
/// like `charactersFixtureSets`. Facts the tests rely on are in CONTRACT.md,
/// "Fixture sets".
const Map<String, MockDomain Function()> identityFixtureSets = {
  'identity.default': _default,
  'identity.empty': _empty,
  'identity.server_error': _serverError,
};
