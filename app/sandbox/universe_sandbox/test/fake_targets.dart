import 'package:characters_details/characters_details.dart' as details;
import 'package:characters_list/characters_list.dart';
import 'package:characters_search/characters_search.dart' as search;
import 'package:flutter/material.dart';
import 'package:universe_wiring/universe_wiring.dart';

class NoNavigator implements CharactersListNavigator {
  @override
  void openCharacter(CharacterId id) {}

  @override
  void openComic(ComicId id) {}

  @override
  void openSearch() {}
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

class _NoSearchNavigator implements search.CharactersSearchNavigator {
  @override
  void openCharacter(search.CharacterId id) {}
}

/// Stands in for the real search (which needs the backend).
class FakeSearch extends search.CharactersSearchFlow {
  FakeSearch(String? query)
    : super(navigator: _NoSearchNavigator(), initialQuery: query);

  @override
  Widget build(BuildContext context) =>
      Text('fake search ${initialQuery ?? '-'}');
}

class FakeTargets implements UniverseRouteTargets {
  @override
  CharactersListFlow characters() => FakeList();

  @override
  search.CharactersSearchFlow charactersSearch({String? query}) =>
      FakeSearch(query);

  @override
  details.CharacterDetailsFlow characterDetails(int id) => FakeDetails(id);
}
