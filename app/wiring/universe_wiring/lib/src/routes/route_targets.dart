import 'package:characters_details/characters_details.dart';
import 'package:characters_list/characters_list.dart';
import 'package:characters_search/characters_search.dart';

/// What the typed routes build (R15): each member returns a feature's `*Flow`.
/// The route file imports only this interface; `UniverseRouteTargetsImpl`
/// (unannotated) supplies the flows' navigators and is registered by
/// `UniverseWiringDIInitializer`. Prefixed with the group, as every wiring's
/// targets are: the app imports all the barrels side by side (T-0041).
abstract interface class UniverseRouteTargets {
  /// The characters list: `/characters`.
  CharactersListFlow characters();

  /// The character search: `/characters/search`, starting with [query] when
  /// given (`?q=`).
  CharactersSearchFlow charactersSearch({String? query});

  /// The profile of one character: `/characters/:id`.
  CharacterDetailsFlow characterDetails(int id);
}
