import 'package:characters_list/src/domain/api/characters_list_api.dart';
import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_mapper.dart';
import 'package:characters_list/src/domain/model/characters_query.dart';
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
}
