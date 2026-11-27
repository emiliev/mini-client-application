import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Signing in as a value, never an exception. Stateless (Tide); the session
/// itself is `mc_session`'s, started by `AuthApi`.
@injectable
class AuthSignInRepository {
  const AuthSignInRepository(this._auth);

  final AuthApi _auth;

  /// Signs in. The email is sent trimmed (the backend matches it ignoring
  /// case and surrounding blanks); the password is sent as typed. On success
  /// the session has started; on failure it is as it was.
  Future<Result<AuthUser, ApiFailure>> signIn({
    required String email,
    required String password,
  }) => _auth.signIn(email: email.trim(), password: password);

  /// Ends the session the last [signIn] started, for a sign-in whose screen
  /// was left before the answer came (the bloc's "leaving cancels"). A
  /// failure to tell the server is not reported: the session is cleared
  /// either way.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
