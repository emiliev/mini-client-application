import 'package:mc_api_errors/mc_api_errors.dart';

/// Why a sign-in did not happen, as the form tells it.
sealed class SignInFailure {
  const SignInFailure();

  /// What the backend's answer means to a sign-in. A `401` from the sign-in
  /// call is always the credentials (the call carries none of its own, so no
  /// session can have expired); anything else is a failure the user may
  /// retry.
  factory SignInFailure.of(ApiFailure failure) => switch (failure) {
    ApiUnauthorized() => const InvalidCredentials(),
    _ => SignInUnavailable(failure),
  };
}

/// The email or password is wrong (`invalid_credentials`). Nothing is signed
/// in; retrying the same values gives the same answer.
final class InvalidCredentials extends SignInFailure {
  const InvalidCredentials();
}

/// The backend could not be asked, or failed (offline, a timeout, a server
/// error). The user may try again.
final class SignInUnavailable extends SignInFailure {
  const SignInUnavailable(this.cause);

  final ApiFailure cause;
}
