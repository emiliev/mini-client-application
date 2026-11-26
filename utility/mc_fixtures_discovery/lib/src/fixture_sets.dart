import 'package:mc_fixtures_discovery/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const DiscoveryMockDomain();
MockDomain _empty() => const EmptyDiscoveryDomain();
MockDomain _serverError() => const FailingDiscoveryDomain();

/// The named fixture sets of this domain (plan 05 §3.4). A test registers
/// them once (`discoveryFixtureSets.forEach(McFixtureSets.register)`) and a
/// scenario switches one on with `the backend serves {'<name>'}`. Facts the
/// tests rely on are in CONTRACT.md, "Fixture sets".
const Map<String, MockDomain Function()> discoveryFixtureSets = {
  'discovery.default': _default,
  'discovery.empty': _empty,
  'discovery.server_error': _serverError,
};
