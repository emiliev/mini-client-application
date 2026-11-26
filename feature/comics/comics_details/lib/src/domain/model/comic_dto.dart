import 'package:freezed_annotation/freezed_annotation.dart';

part 'comic_dto.freezed.dart';
part 'comic_dto.g.dart';

// The wire shapes this feature reads, as the CONTRACT.md files of
// `mc_fixtures_comics` and `mc_fixtures_identity` define them. The contract
// test pins each to the served JSON.
//
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// `GET /v1/comics/:id`: one comic in detail. Every field of the contract is
/// here, so a served body round-trips byte for byte; the domain keeps less.
@Freezed(fromJson: true, toJson: true)
abstract class ComicDto with _$ComicDto {
  @JsonSerializable(explicitToJson: true)
  const factory ComicDto({
    required int id,
    required String title,
    required int issueNumber,
    required int seriesId,

    /// A `YYYY-MM-DD` day. Kept as text: a `DateTime` would not round-trip.
    required String releaseDate,
    required ImageDto cover,
    required String description,
    required SeriesRefDto series,
    required List<CreditDto> creators,
    required List<int> characterIds,

    /// The cast, in `characterIds` order, with what a card shows (T-0041):
    /// no request per character.
    required List<CastMemberDto> characters,
    required PriceDto price,
    required int pageCount,
    required List<VariantDto> variants,
  }) = _ComicDto;

  factory ComicDto.fromJson(Map<String, dynamic> json) =>
      _$ComicDtoFromJson(json);
}

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class ImageDto with _$ImageDto {
  const factory ImageDto({required String path, required String variant}) =
      _ImageDto;

  factory ImageDto.fromJson(Map<String, dynamic> json) =>
      _$ImageDtoFromJson(json);
}

/// The comic's series, by id and title.
@Freezed(fromJson: true, toJson: true)
abstract class SeriesRefDto with _$SeriesRefDto {
  const factory SeriesRefDto({required int id, required String title}) =
      _SeriesRefDto;

  factory SeriesRefDto.fromJson(Map<String, dynamic> json) =>
      _$SeriesRefDtoFromJson(json);
}

/// One credit: a creator and the role's wire name (`cover_artist`, ...).
@Freezed(fromJson: true, toJson: true)
abstract class CreditDto with _$CreditDto {
  const factory CreditDto({
    required int id,
    required String name,
    required String role,
  }) = _CreditDto;

  factory CreditDto.fromJson(Map<String, dynamic> json) =>
      _$CreditDtoFromJson(json);
}

/// A price in minor units of an ISO 4217 currency.
@Freezed(fromJson: true, toJson: true)
abstract class PriceDto with _$PriceDto {
  const factory PriceDto({
    required int amountCents,
    required String currency,
  }) = _PriceDto;

  factory PriceDto.fromJson(Map<String, dynamic> json) =>
      _$PriceDtoFromJson(json);
}

/// A cover variant. Not shown yet (the variants carousel is its own feature).
@Freezed(fromJson: true, toJson: true)
abstract class VariantDto with _$VariantDto {
  @JsonSerializable(explicitToJson: true)
  const factory VariantDto({required String label, required ImageDto cover}) =
      _VariantDto;

  factory VariantDto.fromJson(Map<String, dynamic> json) =>
      _$VariantDtoFromJson(json);
}

/// One entry of the detail's `characters`: a cast member as the characters
/// domain serves it (`id`, `name`, `thumbnail`).
@Freezed(fromJson: true, toJson: true)
abstract class CastMemberDto with _$CastMemberDto {
  @JsonSerializable(explicitToJson: true)
  const factory CastMemberDto({
    required int id,
    required String name,
    required ImageDto thumbnail,
  }) = _CastMemberDto;

  factory CastMemberDto.fromJson(Map<String, dynamic> json) =>
      _$CastMemberDtoFromJson(json);
}

/// `GET/PUT/DELETE /v1/me/favourites/comic/:id`: the answer of a favourite
/// read or write.
@Freezed(fromJson: true, toJson: true)
abstract class FavouriteDto with _$FavouriteDto {
  const factory FavouriteDto({
    required String kind,
    required String id,
    required bool favourite,
  }) = _FavouriteDto;

  factory FavouriteDto.fromJson(Map<String, dynamic> json) =>
      _$FavouriteDtoFromJson(json);
}
