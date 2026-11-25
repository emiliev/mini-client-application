import 'package:mc_test_utils/mc_test_utils.dart';

/// The Gherkin names of the backend failures (plan 05 §3.4): `server_error`,
/// `timeout`, `offline`, `not_found`, `unauthorized`, `malformed`.
const Map<String, BackendFailure> backendFailureNames = {
  'server_error': BackendFailure.serverError,
  'timeout': BackendFailure.timeout,
  'offline': BackendFailure.offline,
  'not_found': BackendFailure.notFound,
  'unauthorized': BackendFailure.unauthorized,
  'malformed': BackendFailure.malformed,
};

/// The failure named [kind]; an unknown name fails, listing the known ones.
BackendFailure backendFailureNamed(String kind) =>
    backendFailureNames[kind] ??
    (throw ArgumentError.value(
      kind,
      'kind',
      'Unknown backend failure. Known: ${backendFailureNames.keys.join(', ')}',
    ));
