import 'package:api_envelope/api_envelope.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'package:retrofit_api/src/character_dto.dart';

part 'characters_api.g.dart';

/// A feature's own `@RestApi` (Tide: one per feature, on the shared `Dio`).
@RestApi()
abstract class CharactersApi {
  factory CharactersApi(Dio dio, {String? baseUrl}) = _CharactersApi;

  @GET('v1/characters')
  Future<ApiResponse<ApiPage<CharacterDto>>> getCharacters({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 30,
    @Query('team') String? team,
  });

  @GET('v1/characters/{id}')
  Future<ApiResponse<CharacterDto>> getCharacter(@Path('id') int id);

  @POST('v1/characters/{id}/favourite')
  Future<void> favourite(@Path('id') int id, @Body() CharacterDto character);
}

/// Hand-written helpers next to the API. T-0027-AC2 edits this body (not a
/// signature) and checks which actions rerun.
extension CharactersApiPaging on CharactersApi {
  Future<ApiResponse<ApiPage<CharacterDto>>> firstPage({String? team}) =>
      getCharacters(limit: 30, team: team);
}
