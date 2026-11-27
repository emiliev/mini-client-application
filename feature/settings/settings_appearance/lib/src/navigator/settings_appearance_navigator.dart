/// What settings_appearance needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/account_wiring` (T-0063). Only blocs call it.
///
/// The ST archetype's one method (plan 01 §6.1). The "About themes" explainer
/// is a page of this flow, not a navigator call.
abstract interface class SettingsAppearanceNavigator {
  /// "Sync across devices", shown while signed out: the app signs someone
  /// in. Completes with true once someone signed in, false when the user
  /// backed out. The feature does not know how signing in works; the
  /// appearance follows whoever signs in by itself (ADR-0013).
  Future<bool> requestSignIn();
}
