import 'package:characters_list/characters_list.dart';
import 'package:universe_wiring/src/flows/character_details_placeholder_flow.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class UniverseRouteTargetsImpl implements UniverseRouteTargets {
  const UniverseRouteTargetsImpl({
    required CharactersListNavigator charactersList,
  }) : _charactersList = charactersList;

  final CharactersListNavigator _charactersList;

  @override
  CharactersListFlow characters() =>
      CharactersListFlow(navigator: _charactersList);

  @override
  CharacterDetailsPlaceholderFlow characterDetails(int id) =>
      CharacterDetailsPlaceholderFlow(id: id);
}
