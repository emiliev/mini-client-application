import 'package:mc_fixtures_editorial/src/domain.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

MockDomain _default() => const TriviaMockDomain();
MockDomain _empty() => const EmptyTriviaDomain();
MockDomain _serverError() => const FailingTriviaDomain();

/// The named fixture sets of this package (plan 05 §3.4), switched on per test
/// like `libraryFixtureSets`. Facts the tests rely on are in CONTRACT.md,
/// "Fixture sets".
const Map<String, MockDomain Function()> editorialFixtureSets = {
  'trivia.default': _default,
  'trivia.empty': _empty,
  'trivia.server_error': _serverError,
};
