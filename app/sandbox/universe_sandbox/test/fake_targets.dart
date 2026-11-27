import 'package:characters_details/characters_details.dart' as details;
import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:universe_wiring/universe_wiring.dart';

class NoNavigator implements CharactersListNavigator {
  @override
  void openCharacter(CharacterId id) {}

  @override
  void openComic(ComicId id) {}
}

class NoDetailsNavigator implements details.CharacterDetailsNavigator {
  @override
  void openComic(details.ComicId id) {}

  @override
  Future<bool> requestSignIn() async => false;
}

/// Stands in for the real profile (which needs the backend): the sandbox
/// tests are about its links.
class FakeDetails extends details.CharacterDetailsFlow {
  FakeDetails(int id)
    : super(
        navigator: NoDetailsNavigator(),
        characterId: details.CharacterId(id),
      );

  @override
  Widget build(BuildContext context) => Text(
    'fake character ${characterId.value}',
    key: const Key('fake.character.details'),
  );
}

class FakeList extends CharactersListFlow {
  FakeList() : super(navigator: NoNavigator());

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('fake.characters'));
}

class FakeTargets implements UniverseRouteTargets {
  @override
  CharactersListFlow characters() => FakeList();

  @override
  details.CharacterDetailsFlow characterDetails(int id) => FakeDetails(id);
}
