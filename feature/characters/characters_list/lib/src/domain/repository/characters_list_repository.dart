import 'package:characters_list/src/domain/api/characters_list_api.dart';
import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/model/character_mapper.dart';
import 'package:characters_list/src/domain/model/characters_query.dart';
import 'package:characters_list/src/domain/model/related_comic.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Pages of characters as values, never exceptions. Stateless (Tide): what
/// the user selected lives in the flow state, not here.
@injectable
class CharactersListRepository {
  const CharactersListRepository(this._api);

  final CharactersListApi _api;

  Future<Result<Page<Character>, ApiFailure>> fetchPage(CharactersQuery q) =>
      apiCall(
        () async => (await _api.getCharacters(
          offset: q.offset,
          limit: q.limit,
          team: q.teamId,
        )).toDomain(),
      );

  /// The first [limit] comics [character] appears in, in title order.
  Future<Result<List<RelatedComic>, ApiFailure>> fetchRelatedComics(
    CharacterId character, {
    int limit = relatedComicsLimit,
  }) => apiCall(
    () async => [
      for (final dto in (await _api.getComicsOf(
        characterId: character.value,
        limit: limit,
      )).results)
        dto.toDomain(),
    ],
  );
}

/// How many related comics the preview lists.
const int relatedComicsLimit = 5;
