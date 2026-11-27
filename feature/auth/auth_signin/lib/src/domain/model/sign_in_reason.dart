/// What the user is signing in for, so the screen can say so ("Sign in to
/// keep your favourites"). A closed set of codes, never text: the code
/// travels in a link (`/auth/sign-in?reason=favourites`), and a link must
/// not be able to put its own words on the screen. An unknown code is no
/// reason.
enum SignInReason {
  favourites,
  readingLists,
  cart,
  triviaResults,
  appearanceSync;

  /// The reason named by [code] (as in a link), or null for none or an
  /// unknown one.
  static SignInReason? parse(String? code) =>
      code == null ? null : SignInReason.values.asNameMap()[code];
}
