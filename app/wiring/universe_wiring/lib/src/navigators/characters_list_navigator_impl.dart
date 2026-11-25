import 'dart:async';

import 'package:characters_list/characters_list.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';
import 'package:universe_wiring/src/routes/characters_routes.dart';

/// characters_list's way out of the feature: its intents become typed routes.
@LazySingleton(as: CharactersListNavigator)
class CharactersListNavigatorImpl implements CharactersListNavigator {
  CharactersListNavigatorImpl(this._router);

  final GoRouter _router;

  @override
  void openCharacter(CharacterId id) {
    unawaited(_router.push(CharacterDetailsRoute(id: id.value).location));
  }
}
