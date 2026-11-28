import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_dto.freezed.dart';
part 'store_dto.g.dart';

// The wire shapes this feature reads, as `mc_fixtures_commerce`'s
// CONTRACT.md defines them. The contract test pins each to the served JSON
// (every field of the store routes, so a body round-trips byte for byte).
//
// Money is integer cents in every field (`...Cents`): never a `double`.
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class ImageDto with _$ImageDto {
  const factory ImageDto({required String path, required String variant}) =
      _ImageDto;

  factory ImageDto.fromJson(Map<String, dynamic> json) =>
      _$ImageDtoFromJson(json);
}

/// A product: a comic with the store's own price (cents) and stock.
@Freezed(fromJson: true, toJson: true)
abstract class ProductDto with _$ProductDto {
  @JsonSerializable(explicitToJson: true)
  const factory ProductDto({
    required int id,
    required String title,
    required String categoryId,
    required int issueNumber,
    required int seriesId,
    required int priceCents,

    /// Null unless the product is one of the deals.
    required int? dealPriceCents,
    required String currency,
    required int stock,
    required ImageDto cover,
  }) = _ProductDto;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);
}

/// Where a banner leads: exactly one of the ids or the query, by [type].
@Freezed(fromJson: true, toJson: true)
abstract class BannerTargetDto with _$BannerTargetDto {
  @JsonSerializable(includeIfNull: false)
  const factory BannerTargetDto({
    /// `comic`, `category` or `search`.
    required String type,
    int? comicId,
    String? categoryId,
    String? query,
  }) = _BannerTargetDto;

  factory BannerTargetDto.fromJson(Map<String, dynamic> json) =>
      _$BannerTargetDtoFromJson(json);
}

/// One banner of `GET /v1/store/banners`.
@Freezed(fromJson: true, toJson: true)
abstract class BannerDto with _$BannerDto {
  @JsonSerializable(explicitToJson: true)
  const factory BannerDto({
    required String id,
    required String title,
    required String subtitle,
    required ImageDto image,
    required BannerTargetDto target,
  }) = _BannerDto;

  factory BannerDto.fromJson(Map<String, dynamic> json) =>
      _$BannerDtoFromJson(json);
}

/// `GET /v1/store/banners`.
@Freezed(fromJson: true, toJson: true)
abstract class BannersDto with _$BannersDto {
  @JsonSerializable(explicitToJson: true)
  const factory BannersDto({required List<BannerDto> banners}) = _BannersDto;

  factory BannersDto.fromJson(Map<String, dynamic> json) =>
      _$BannersDtoFromJson(json);
}

/// One deal of `GET /v1/store/deals`.
@Freezed(fromJson: true, toJson: true)
abstract class DealDto with _$DealDto {
  @JsonSerializable(explicitToJson: true)
  const factory DealDto({
    required ProductDto product,
    required int originalPriceCents,
    required int dealPriceCents,
    required int discountPercent,
    required String currency,

    /// An ISO 8601 instant. Kept as text: it round-trips.
    required String endsAt,
  }) = _DealDto;

  factory DealDto.fromJson(Map<String, dynamic> json) =>
      _$DealDtoFromJson(json);
}

/// `GET /v1/store/deals`.
@Freezed(fromJson: true, toJson: true)
abstract class DealsDto with _$DealsDto {
  @JsonSerializable(explicitToJson: true)
  const factory DealsDto({required List<DealDto> deals}) = _DealsDto;

  factory DealsDto.fromJson(Map<String, dynamic> json) =>
      _$DealsDtoFromJson(json);
}

/// One category of `GET /v1/store/categories`.
@Freezed(fromJson: true, toJson: true)
abstract class CategoryDto with _$CategoryDto {
  @JsonSerializable(explicitToJson: true)
  const factory CategoryDto({
    required String id,
    required String name,
    required int count,
    required ImageDto image,
  }) = _CategoryDto;

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);
}

/// `GET /v1/store/categories`.
@Freezed(fromJson: true, toJson: true)
abstract class CategoriesDto with _$CategoriesDto {
  @JsonSerializable(explicitToJson: true)
  const factory CategoriesDto({required List<CategoryDto> categories}) =
      _CategoriesDto;

  factory CategoriesDto.fromJson(Map<String, dynamic> json) =>
      _$CategoriesDtoFromJson(json);
}

/// `GET /v1/store/featured`.
@Freezed(fromJson: true, toJson: true)
abstract class FeaturedDto with _$FeaturedDto {
  @JsonSerializable(explicitToJson: true)
  const factory FeaturedDto({required List<ProductDto> products}) =
      _FeaturedDto;

  factory FeaturedDto.fromJson(Map<String, dynamic> json) =>
      _$FeaturedDtoFromJson(json);
}

/// What the store home reads of `GET /v1/me/cart`: the summary only (the
/// lines and promotions are the cart screen's, not this feature's).
@Freezed(fromJson: true, toJson: true)
abstract class CartSummaryDto with _$CartSummaryDto {
  const factory CartSummaryDto({
    required String currency,
    required int itemCount,
    required int totalCents,
  }) = _CartSummaryDto;

  factory CartSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$CartSummaryDtoFromJson(json);
}
