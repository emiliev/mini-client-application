import 'package:dio/dio.dart';
import 'package:discovery_search/src/domain/model/search_dto.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';

part 'discovery_search_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`).
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class DiscoverySearchApi {
  @factoryMethod
  factory DiscoverySearchApi(Dio dio) = _DiscoverySearchApi;

  /// Ranked results for [q] (at least 2 characters, else `400`), one group
  /// per type, at most [limit] per group. Leaving `types` out asks for both.
  @GET('v1/search')
  Future<SearchResponseDto> search(
    @Query('q') String q, {
    @Query('limit') int? limit,
  });

  /// The best 5 distinct titles across types for [q].
  @GET('v1/search/suggestions')
  Future<SuggestionsDto> suggestions(@Query('q') String q);
}
