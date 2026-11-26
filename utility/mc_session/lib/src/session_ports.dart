import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/src/auth_tokens.dart';
import 'package:mc_storage/mc_storage.dart';

enum AuthStatus { signedIn, signedOut }

/// Published on the [EventBus] whenever the session starts or ends.
class SessionChanged extends BusEvent {
  const SessionChanged(this.status);

  final AuthStatus status;

  @override
  bool operator ==(Object other) =>
      other is SessionChanged && other.status == status;

  @override
  int get hashCode => Object.hash(SessionChanged, status);

  @override
  String toString() => 'SessionChanged(${status.name})';
}

/// The read side: what features, the router guard and the API client see.
abstract interface class SessionReader {
  AuthStatus get status;

  bool get isSignedIn;

  /// Null when signed out.
  String? get userId;

  /// Null when signed out.
  String? get accessToken;

  /// Null when signed out.
  String? get refreshToken;

  /// Each change of [status], in order. A broadcast stream: it has no replay,
  /// so read [status] for the current value.
  Stream<AuthStatus> get authState;
}

/// The write side: only the sign-in flow and the auth interceptor use it.
///
/// Every call changes the in-memory state at once, so the next request
/// already sees it, and returns when the change is saved. A save failure is
/// returned as a value; the in-memory state stays as changed.
abstract interface class SessionWriter {
  /// Starts a session (replacing any current one) and publishes
  /// `SessionChanged(signedIn)`.
  Future<Result<void, StorageFailure>> signIn({
    required String userId,
    required AuthTokens tokens,
  });

  /// Swaps the tokens after a refresh. No event. A no-op when signed out, so
  /// a refresh that lands after a sign-out cannot bring the session back.
  Future<Result<void, StorageFailure>> updateTokens(AuthTokens tokens);

  /// Ends the session and publishes `SessionChanged(signedOut)` if one was
  /// active. Always clears the store, so it also heals a corrupt value.
  Future<Result<void, StorageFailure>> signOut();
}
