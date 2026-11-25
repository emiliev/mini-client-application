import 'package:characters_list/src/domain/model/character_dto.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:retrofit/retrofit.dart';

part 'characters_list_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`).
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class CharactersListApi {
  @factoryMethod
  factory CharactersListApi(Dio dio) = _CharactersListApi;

  @GET('v1/characters')
  Future<ApiPage<CharacterDto>> getCharacters({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 30,
    @Query('team') String? team,
  });
}
