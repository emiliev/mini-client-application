import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:universe_wiring/universe_wiring.dart';

class NoNavigator implements CharactersListNavigator {
  @override
  void openCharacter(CharacterId id) {}
}

class FakeList extends CharactersListFlow {
  FakeList() : super(navigator: NoNavigator());

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('fake.characters'));
}

class FakeTargets implements RouteTargets {
  @override
  CharactersListFlow characters() => FakeList();

  @override
  CharacterDetailsPlaceholderFlow characterDetails(int id) =>
      CharacterDetailsPlaceholderFlow(id: id);
}
