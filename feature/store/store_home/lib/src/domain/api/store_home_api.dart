import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:retrofit/retrofit.dart';
import 'package:store_home/src/domain/model/store_dto.dart';

part 'store_home_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature): the five section endpoints, a category's products, and the cart
/// summary (`mc_fixtures_commerce` CONTRACT.md). The `Dio` comes from the
/// root container (a `RootImport`), with the auth interceptor on it, so the
/// cart call carries the bearer.
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class StoreHomeApi {
  @factoryMethod
  factory StoreHomeApi(Dio dio) = _StoreHomeApi;

  @GET('v1/store/banners')
  Future<BannersDto> getBanners();

  @GET('v1/store/deals')
  Future<DealsDto> getDeals();

  @GET('v1/store/categories')
  Future<CategoriesDto> getCategories();

  /// One category's products in title order; `404` for an unknown category.
  @GET('v1/store/categories/{id}/products')
  Future<ApiPage<ProductDto>> getCategoryProducts(
    @Path('id') String id, {
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
  });

  @GET('v1/store/featured')
  Future<FeaturedDto> getFeatured();

  /// The signed-in user's cart (the summary fields of it). Needs the bearer.
  /// Pass `authPinned(epoch)` as [extras] to send it only for that session.
  @GET('v1/me/cart')
  Future<CartSummaryDto> getCart({
    @Extras() Map<String, dynamic> extras = const {},
  });
}
