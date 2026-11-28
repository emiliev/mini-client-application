/// What settings_home needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/account_wiring` (T-0070). Only blocs call it.
abstract interface class SettingsHomeNavigator {
  /// The Appearance row: opens the appearance settings above this page.
  void openAppearance();

  /// "Sign in", shown while signed out: the app signs someone in. Completes
  /// with true once someone signed in, false when the user backed out. The
  /// page follows the session by itself, so the answer only ends the wait.
  Future<bool> requestSignIn();

  /// "Sign out", shown while signed in: the app ends the session (the auth
  /// port, `AuthApi.signOut`, which also tells the server). The feature never
  /// signs anyone out itself; it only reads the session.
  Future<void> signOut();
}
