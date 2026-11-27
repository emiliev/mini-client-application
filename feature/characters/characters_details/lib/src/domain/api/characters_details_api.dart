import 'package:characters_details/src/domain/model/character_dto.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'characters_details_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`), with
/// the auth interceptor on it, so the favourite calls carry the bearer.
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class CharacterDetailsApi {
  @factoryMethod
  factory CharacterDetailsApi(Dio dio) = _CharacterDetailsApi;

  /// The character in detail; `404` for an unknown id.
  @GET('v1/characters/{id}')
  Future<CharacterDto> getCharacter(@Path('id') int id);

  /// A page of the comics that feature the character (the comics domain's
  /// reverse lookup), in title order.
  @GET('v1/comics')
  Future<ComicsPageDto> getComics(
    @Query('characterId') int characterId,
    @Query('limit') int limit,
  );

  /// `200` when the character is a favourite of the signed-in user, `404`
  /// when it is not. Needs the bearer.
  @GET('v1/me/favourites/character/{id}')
  Future<FavouriteDto> getFavourite(@Path('id') int id);

  /// Marks the character as a favourite (idempotent). Needs the bearer. Pass
  /// `authPinned(epoch)` as [extras] to send it only for that session.
  @PUT('v1/me/favourites/character/{id}')
  Future<FavouriteDto> putFavourite(
    @Path('id') int id, {
    @Extras() Map<String, dynamic> extras = const {},
  });

  /// Removes the character from the favourites (idempotent). Needs the
  /// bearer. Pass `authPinned(epoch)` as [extras] to send it only for that
  /// session.
  @DELETE('v1/me/favourites/character/{id}')
  Future<FavouriteDto> deleteFavourite(
    @Path('id') int id, {
    @Extras() Map<String, dynamic> extras = const {},
  });
}
