import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_platform/src/data/flags.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// `GET /v1/flags` of the default set. Auth is optional: a valid bearer (the
/// same shape rule as `GET /v1/me`, `userForAuthorization`) adds that user's
/// targeting; a missing, malformed, expired or unknown bearer is simply
/// anonymous, never `401`, so a client can always read its flags.
MockResponse defaultFlags(MockRequest request, MockContext context) {
  final user = userForAuthorization(request.headers['authorization']);
  return MockResponse.ok(flagsBodyDefault(user?.id));
}

/// The `platform.empty` set and scenario.
MockResponse emptyFlags(MockRequest request, MockContext context) =>
    MockResponse.ok(flagsBodyEmpty());

/// The `platform.flags_malformed` set and scenario.
MockResponse malformedFlags(MockRequest request, MockContext context) =>
    MockResponse.ok(flagsBodyMalformed());

/// The `server_error` set: the exact body the `platform.server_error`
/// scenario's `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );
