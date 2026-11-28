import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:characters_list/characters_list.dart';
import 'package:injectable/injectable.dart';
import 'package:universe_wiring/src/routes/characters_routes.dart';

/// characters_list's way out of the feature: its intents become routes. A
/// character is this group's (a typed route); a comic is the publishing
/// group's, so it goes through `AppLocations` (plan 01 §4.2).
/// It holds the [RouterRef], not a router, and asks for the live router at
/// each call, so after the app's router is replaced (a detach, a new boot) it
/// still pushes to the one on screen.
@LazySingleton(as: CharactersListNavigator)
class CharactersListNavigatorImpl implements CharactersListNavigator {
  CharactersListNavigatorImpl(this._routerRef);

  final RouterRef _routerRef;

  @override
  void openCharacter(CharacterId id) {
    unawaited(
      _routerRef.router.push(CharacterDetailsRoute(id: id.value).location),
    );
  }

  @override
  void openComic(ComicId id) {
    unawaited(_routerRef.router.push(AppLocations.comic(id.value)));
  }

  /// The search is this group's (a typed route), and a push: Back returns to
  /// the list (T-0071).
  @override
  void openSearch() {
    unawaited(_routerRef.router.push(const CharactersSearchRoute().location));
  }
}
