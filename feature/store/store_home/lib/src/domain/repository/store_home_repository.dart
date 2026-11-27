import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_paging/mc_paging.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:store_home/src/domain/api/store_home_api.dart';
import 'package:store_home/src/domain/model/category_id.dart';
import 'package:store_home/src/domain/model/store.dart';
import 'package:store_home/src/domain/model/store_mapper.dart';

/// The store's sections as values, never exceptions: one method per
/// section, each its own request, so one failing never touches another.
/// Stateless (Tide): what the page shows lives in its blocs and the flow
/// state.
@injectable
class StoreHomeRepository {
  const StoreHomeRepository(this._api);

  final StoreHomeApi _api;

  Future<Result<List<StoreBanner>, ApiFailure>> fetchBanners() => apiCall(
    () async => [
      for (final b in (await _api.getBanners()).banners) b.toDomain(),
    ],
  );

  Future<Result<List<Deal>, ApiFailure>> fetchDeals() => apiCall(
    () async => [for (final d in (await _api.getDeals()).deals) d.toDomain()],
  );

  Future<Result<List<StoreCategory>, ApiFailure>> fetchCategories() => apiCall(
    () async => [
      for (final c in (await _api.getCategories()).categories) c.toDomain(),
    ],
  );

  Future<Result<List<Product>, ApiFailure>> fetchFeatured() => apiCall(
    () async => [
      for (final p in (await _api.getFeatured()).products) p.toDomain(),
    ],
  );

  /// One page of [category]'s products. An unknown category is
  /// [ApiNotFound].
  Future<Result<Page<Product>, ApiFailure>> fetchCategoryPage(
    CategoryId category,
    PageRequest request,
  ) => apiCall(
    () async => (await _api.getCategoryProducts(
      category.value,
      offset: request.offset,
      limit: request.limit,
    )).toDomain(),
  );

  /// The cart summary of the session [epoch]: the request is pinned to it
  /// (T-0050), so it is never sent with another user's bearer; if the
  /// session changed before it left, the answer is [ApiUnauthorized].
  Future<Result<CartSummary, ApiFailure>> fetchCart({required int epoch}) =>
      apiCall(
        () async => (await _api.getCart(extras: authPinned(epoch))).toDomain(),
      );
}
