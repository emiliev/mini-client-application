import 'package:comics_details/src/domain/model/character_id.dart';
import 'package:comics_details/src/domain/model/creator_id.dart';

/// What comics_details needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/publishing_wiring` (T-0041). Only blocs call it.
abstract interface class ComicsDetailsNavigator {
  /// A character in the cast section: hands over to the character's page.
  void openCharacter(CharacterId id);

  /// A creator in the credits: hands over to the creator's page.
  void openCreator(CreatorId id);

  /// The favourite needs a signed-in user. Completes with true once someone
  /// signed in, false when the user backed out. The feature does not know
  /// how signing in works; the app decides (a sheet, a route).
  Future<bool> requestSignIn();
}
