import 'package:trivia_quiz/src/domain/model/comic_id.dart';

/// What trivia_quiz needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/chronicle_wiring` (T-0064). Only blocs call it.
///
/// The IX archetype's two methods (plan 01 §6.1).
abstract interface class TriviaQuizNavigator {
  /// A question of the finished round is about this comic: hands over to the
  /// comic's page. The results page offers it, so a round is never left
  /// half-played for it.
  void openComic(ComicId id);

  /// Saving a score needs a signed-in user. Completes with true once someone
  /// signed in, false when the user backed out. The feature does not know
  /// how signing in works; the app decides.
  Future<bool> requestSignIn();
}
