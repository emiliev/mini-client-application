import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:characters_search/characters_search.dart';
import 'package:injectable/injectable.dart';
import 'package:universe_wiring/src/routes/characters_routes.dart';

/// characters_search's way out of the feature: its intent becomes a route. A
/// character is this group's (a typed route), and the profile opens on top of
/// the results (a push), so Back returns to them.
/// It holds the [RouterRef], not a router, and asks for the live router at
/// each call, so after the app's router is replaced it still pushes to the
/// one on screen.
@LazySingleton(as: CharactersSearchNavigator)
class CharactersSearchNavigatorImpl implements CharactersSearchNavigator {
  CharactersSearchNavigatorImpl(this._routerRef);

  final RouterRef _routerRef;

  @override
  void openCharacter(CharacterId id) {
    unawaited(
      _routerRef.router.push(CharacterDetailsRoute(id: id.value).location),
    );
  }
}
