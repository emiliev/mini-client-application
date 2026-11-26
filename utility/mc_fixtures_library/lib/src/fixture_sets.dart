import 'package:mc_fixtures_library/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const LibraryMockDomain();
MockDomain _empty() => const EmptyLibraryDomain();
MockDomain _serverError() => const FailingLibraryDomain();

/// The named fixture sets of this domain (plan 05 §3.4), switched on per test
/// like `discoveryFixtureSets`. Facts the tests rely on are in CONTRACT.md,
/// "Fixture sets".
const Map<String, MockDomain Function()> libraryFixtureSets = {
  'library.default': _default,
  'library.empty': _empty,
  'library.server_error': _serverError,
};
