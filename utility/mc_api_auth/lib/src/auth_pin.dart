/// `Options.extra` key: the session epoch (`SessionReader.epoch`) a request
/// was started for. The auth interceptor sends a request that carries it only
/// while that session is still current; otherwise it rejects the request
/// before any bearer is attached, and the caller gets
/// `ApiFailure.unauthorized('The session changed')` (through `apiCall`).
///
/// Set it with [authPinned]. A request without it keeps the unpinned
/// behaviour: it carries whatever token is current when it is sent.
const String mcSessionEpoch = 'mc_api_auth.pinned_epoch';

/// The `extra` map that pins a request to [epoch]: the session epoch the
/// caller checked before starting the write.
///
/// Why: Dio runs every request interceptor in a new event-loop turn, so a
/// user switch between the caller's own check and the send would otherwise
/// give the request the new user's bearer. Pass the epoch the caller's check
/// used, for example
/// `Options(extra: authPinned(session.epoch))`, or a retrofit
/// `@Extras() Map<String, dynamic> extras` parameter.
Map<String, Object?> authPinned(int epoch) => {mcSessionEpoch: epoch};
