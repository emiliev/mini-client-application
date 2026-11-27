import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The screen name of the flow's one page: its `McFlowPage` name, which
/// `AnalyticsFlowObserver` tracks. It equals the app route's name
/// (`/characters/:id` is `character_details`), so it is not tracked twice
/// (ADR-0012).
const String characterDetailsScreen = 'character_details';

/// The signed-in user saved the character among their favourites.
const String characterFavouritedEvent = 'character_favourited';

/// The profile's analytics vocabulary over the blocs' pure-Dart port
/// (`AnalyticsTracker`, R15, ADR-0012): the event and its parameters are
/// spelled once, here.
extension CharacterTracking on AnalyticsTracker {
  /// `character_favourited` with `id`, the character's id. Only a saved
  /// favourite counts: not a removal, a failed write or a sign-in that was
  /// backed out of.
  void characterFavourited(CharacterId id) =>
      trackEvent(characterFavouritedEvent, {'id': id.value});
}
