import 'package:characters_search/src/domain/model/character_id.dart';

/// What characters_search needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/universe_wiring` (T-0071). Only blocs call it.
abstract interface class CharactersSearchNavigator {
  /// A character in the results: hands over to the character's profile
  /// (`characters_details`).
  void openCharacter(CharacterId id);
}
