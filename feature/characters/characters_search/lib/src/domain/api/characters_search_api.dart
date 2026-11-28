import 'package:characters_search/src/domain/model/character_dto.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:retrofit/retrofit.dart';

part 'characters_search_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`).
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class CharactersSearchApi {
  @factoryMethod
  factory CharactersSearchApi(Dio dio) = _CharactersSearchApi;

  /// One page of the characters whose name starts with [nameStartsWith].
  /// A null [team] is left out of the request.
  @GET('v1/characters')
  Future<ApiPage<CharacterDto>> getCharacters({
    @Query('nameStartsWith') required String nameStartsWith,
    @Query('orderBy') required String orderBy,
    @Query('team') String? team,
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 30,
  });
}
