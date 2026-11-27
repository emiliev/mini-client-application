import 'package:comics_details/src/domain/model/comic_dto.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'comics_details_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`), with
/// the auth interceptor on it, so the favourite calls carry the bearer.
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class ComicsDetailsApi {
  @factoryMethod
  factory ComicsDetailsApi(Dio dio) = _ComicsDetailsApi;

  /// The comic in detail; `404` for an unknown id.
  @GET('v1/comics/{id}')
  Future<ComicDto> getComic(@Path('id') int id);

  /// `200` when the comic is a favourite of the signed-in user, `404` when
  /// it is not. Needs the bearer.
  @GET('v1/me/favourites/comic/{id}')
  Future<FavouriteDto> getFavourite(@Path('id') int id);

  /// Marks the comic as a favourite (idempotent). Needs the bearer. Pass
  /// `authPinned(epoch)` as [extras] to send it only for that session.
  @PUT('v1/me/favourites/comic/{id}')
  Future<FavouriteDto> putFavourite(
    @Path('id') int id, {
    @Extras() Map<String, dynamic> extras = const {},
  });

  /// Removes the comic from the favourites (idempotent). Needs the bearer.
  /// Pass `authPinned(epoch)` as [extras] to send it only for that session.
  @DELETE('v1/me/favourites/comic/{id}')
  Future<FavouriteDto> deleteFavourite(
    @Path('id') int id, {
    @Extras() Map<String, dynamic> extras = const {},
  });
}
