import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_dto.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:retrofit/retrofit.dart';

part 'reading_list_editor_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`), with
/// the auth interceptor on it, so every `v1/me/lists` call carries the
/// bearer.
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class ReadingListEditorApi {
  @factoryMethod
  factory ReadingListEditorApi(Dio dio) = _ReadingListEditorApi;

  /// One of the signed-in user's lists; `404` for an unknown id and for
  /// another user's list.
  @GET('v1/me/lists/{id}')
  Future<ReadingListDto> getList(@Path('id') String id);

  /// A new list (`201`, the list in the detail shape). Never retried.
  @POST('v1/me/lists')
  Future<ReadingListDto> createList(@Body() CreateReadingListDto body);

  /// The name, description and visibility of a list.
  @PUT('v1/me/lists/{id}')
  Future<ReadingListDto> updateList(
    @Path('id') String id,
    @Body() ReadingListDetailsDto body,
  );

  /// The comics of a list, in order.
  @PUT('v1/me/lists/{id}/items')
  Future<ReadingListDto> replaceItems(
    @Path('id') String id,
    @Body() ReadingListItemsDto body,
  );

  /// The picker's search: comics whose title starts with [titleStartsWith]
  /// (case-insensitive), in title order; all comics when it is null.
  @GET('v1/comics')
  Future<ApiPage<ComicHitDto>> searchComics({
    @Query('titleStartsWith') String? titleStartsWith,
    @Query('limit') int limit = 20,
  });
}
