import 'package:characters_list/characters_list.dart';
import 'package:flutter/widgets.dart';
import 'package:universe_wiring/src/pages/character_details_placeholder_page.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';

/// Builds each route's page from the feature barrels (R15: unannotated, so no
/// generator reads it).
class RouteTargetsImpl implements RouteTargets {
  const RouteTargetsImpl({required CharactersListNavigator charactersList})
    : _charactersList = charactersList;

  final CharactersListNavigator _charactersList;

  @override
  Widget characters(BuildContext context) =>
      CharactersListFlow(navigator: _charactersList);

  @override
  Widget characterDetails(BuildContext context, int id) =>
      CharacterDetailsPlaceholderPage(id: id);
}
