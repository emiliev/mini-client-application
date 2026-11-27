import 'package:mc_test_utils/mc_test_utils.dart';

final Expando<List<RecordedRequest>> _attempts = Expando(
  'requests the app tried to send',
);

/// Every request that entered the root `Dio` in the current test, in order,
/// whether or not it reached the backend (an interceptor may reject it).
List<RecordedRequest> requestsTheAppTriedToSend() =>
    _attempts[McTestSession.current] ??= [];
