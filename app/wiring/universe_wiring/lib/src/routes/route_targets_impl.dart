import 'package:characters_details/characters_details.dart' as details;
import 'package:characters_list/characters_list.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class UniverseRouteTargetsImpl implements UniverseRouteTargets {
  const UniverseRouteTargetsImpl({
    required CharactersListNavigator charactersList,
    required details.CharacterDetailsNavigator characterDetails,
  }) : _charactersList = charactersList,
       _characterDetails = characterDetails;

  final CharactersListNavigator _charactersList;
  final details.CharacterDetailsNavigator _characterDetails;

  @override
  CharactersListFlow characters() =>
      CharactersListFlow(navigator: _charactersList);

  @override
  details.CharacterDetailsFlow characterDetails(int id) =>
      details.CharacterDetailsFlow(
        navigator: _characterDetails,
        characterId: details.CharacterId(id),
      );
}
