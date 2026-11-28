import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/model/comic_id.dart';

/// What characters_list needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/universe_wiring` (T-0033). Only blocs call it.
///
/// `requestSignIn` (plan 01 §3.3) joins when this feature needs a signed-in
/// user.
abstract interface class CharactersListNavigator {
  /// The preview's "See full profile": hands over to characters_details.
  void openCharacter(CharacterId id);

  /// A related comic on the preview: hands over to comics_details (T-0041).
  void openComic(ComicId id);

  /// The app bar's search action: hands over to characters_search (T-0071).
  void openSearch();
}
