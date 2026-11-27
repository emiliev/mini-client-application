import 'package:characters_details/src/domain/model/comic_id.dart';

/// What characters_details needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/universe_wiring` (T-0067). Only blocs call it.
abstract interface class CharacterDetailsNavigator {
  /// A comic in the "Comics" row: hands over to the comic's page.
  void openComic(ComicId id);

  /// The favourite needs a signed-in user. Completes with true once someone
  /// signed in, false when the user backed out. The feature does not know
  /// how signing in works; the app decides (a sheet, a route).
  Future<bool> requestSignIn();
}
