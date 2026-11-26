import 'package:characters_list/characters_list.dart';
import 'package:universe_wiring/src/flows/character_details_placeholder_flow.dart';

/// What the typed routes build (R15): each member returns a feature's `*Flow`.
/// The route file imports only this interface; `RouteTargetsImpl`
/// (unannotated) supplies the flows' navigators and is registered by
/// `UniverseWiringDIInitializer`.
abstract interface class RouteTargets {
  /// The characters list: `/characters`.
  CharactersListFlow characters();

  /// The details of one character: `/characters/:id`. A placeholder until
  /// `characters_details` exists.
  CharacterDetailsPlaceholderFlow characterDetails(int id);
}
