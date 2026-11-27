/// How the sign-in flow ended (plan 01 §4.3): the flow's result.
///
/// A user who leaves by Back from the form gives no result at all (the
/// route's own pop gives its caller null), which callers treat as
/// [cancelled].
enum SignInResult {
  /// Someone is signed in now: the credentials were accepted.
  signedIn,

  /// The user chose not to sign in (Not now).
  cancelled,
}
