/// What auth_signin needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/account_wiring` (T-0066).
///
/// It has no outbound methods yet: the form ends with a result
/// (`AuthSignInFlow.onComplete`) and the app decides where that leads (back
/// to the caller, or to the link that asked for the sign-in). Sign-up and
/// password reset would add intents here.
abstract interface class AuthSignInNavigator {}
