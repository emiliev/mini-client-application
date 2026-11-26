import 'package:characters_list/characters_list.dart';
import 'package:universe_wiring/src/flows/character_details_placeholder_flow.dart';

/// What the typed routes build (R15): each member returns a feature's `*Flow`.
/// The route file imports only this interface; `UniverseRouteTargetsImpl`
/// (unannotated) supplies the flows' navigators and is registered by
/// `UniverseWiringDIInitializer`. Prefixed with the group, as every wiring's
/// targets are: the app imports all the barrels side by side (T-0041).
abstract interface class UniverseRouteTargets {
  /// The characters list: `/characters`.
  CharactersListFlow characters();

  /// The details of one character: `/characters/:id`. A placeholder until
  /// `characters_details` exists.
  CharacterDetailsPlaceholderFlow characterDetails(int id);
}
