import 'package:characters_list/src/domain/model/character_id.dart';

/// What characters_list needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/universe_wiring` (T-0033). Only blocs call it.
///
/// `openComic` and `requestSignIn` (plan 01 §3.3) join when the features
/// that need them exist.
abstract interface class CharactersListNavigator {
  /// The preview's "See full profile": hands over to characters_details.
  void openCharacter(CharacterId id);
}
