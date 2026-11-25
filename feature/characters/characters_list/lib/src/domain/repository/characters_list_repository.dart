import 'package:characters_list/src/domain/api/characters_list_api.dart';
import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/model/character_mapper.dart';
import 'package:characters_list/src/domain/model/characters_query.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Pages of characters as values, never exceptions.
///
/// One per flow (a lazy singleton in the flow's own container, R17): the list
/// bloc loads pages through it and the preview bloc reads the character the
/// user tapped from what it loaded, with no second request.
@lazySingleton
class CharactersListRepository {
  CharactersListRepository(this._api);

  final CharactersListApi _api;
  final Map<CharacterId, Character> _loaded = {};

  Future<Result<Page<Character>, ApiFailure>> fetchPage(CharactersQuery q) =>
      apiCall(() async {
        final page = (await _api.getCharacters(
          offset: q.offset,
          limit: q.limit,
          team: q.teamId,
        )).toDomain();
        for (final character in page.results) {
          _loaded[character.id] = character;
        }
        return page;
      });

  /// A character from a page this repository loaded. The preview opens only
  /// from a tile of the list, so a miss is a bug and throws.
  Character loaded(CharacterId id) =>
      _loaded[id] ??
      (throw StateError('Character $id was never loaded by this flow.'));
}
