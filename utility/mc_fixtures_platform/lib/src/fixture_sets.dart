import 'package:mc_fixtures_platform/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const PlatformMockDomain();
MockDomain _empty() => const EmptyPlatformDomain();
MockDomain _malformed() => const MalformedFlagsPlatformDomain();
MockDomain _serverError() => const FailingPlatformDomain();

/// The named fixture sets of this domain (plan 05 §3.4), switched on per test
/// like `libraryFixtureSets`. Facts the tests rely on are in CONTRACT.md,
/// "Fixture sets".
const Map<String, MockDomain Function()> platformFixtureSets = {
  'platform.default': _default,
  'platform.empty': _empty,
  'platform.flags_malformed': _malformed,
  'platform.server_error': _serverError,
};
