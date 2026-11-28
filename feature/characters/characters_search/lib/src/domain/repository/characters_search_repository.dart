import 'package:characters_search/src/domain/api/characters_search_api.dart';
import 'package:characters_search/src/domain/model/character.dart';
import 'package:characters_search/src/domain/model/character_facets.dart';
import 'package:characters_search/src/domain/model/character_mapper.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Pages of matching characters as values, never exceptions. Stateless
/// (Tide): which query and facets are on screen live in the bloc.
@injectable
class CharactersSearchRepository {
  const CharactersSearchRepository(this._api);

  final CharactersSearchApi _api;

  Future<Result<Page<Character>, ApiFailure>> fetchPage(
    CharactersSearchQuery query,
  ) => apiCall(
    () async => (await _api.getCharacters(
      nameStartsWith: query.prefix,
      orderBy: query.facets.sort.wireName,
      team: query.facets.team,
      offset: query.offset,
      limit: query.limit,
    )).toDomain(),
  );
}
