import 'package:discovery_search/src/domain/model/character_id.dart';
import 'package:discovery_search/src/domain/model/comic_id.dart';

/// What discovery_search needs from outside: intents in the feature's own
/// language, never routes (plan 01 §4.1). Implemented in
/// `app/wiring/discovery_wiring` (T-0046). Only blocs call it.
abstract interface class DiscoverySearchNavigator {
  /// A character in the results: hands over to the character's page.
  void openCharacter(CharacterId id);

  /// A comic in the results: hands over to the comic's page.
  void openComic(ComicId id);
}
