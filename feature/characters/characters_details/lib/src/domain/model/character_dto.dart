import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_dto.freezed.dart';
part 'character_dto.g.dart';

// The wire shapes this feature reads, as the CONTRACT.md files of
// `mc_fixtures_characters`, `mc_fixtures_comics` and `mc_fixtures_identity`
// define them. The contract test pins each to the served JSON.
//
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// `GET /v1/characters/:id`: one character in detail. Every field of the
/// contract is here, so a served body round-trips; the domain keeps less.
@Freezed(fromJson: true, toJson: true)
abstract class CharacterDto with _$CharacterDto {
  @JsonSerializable(explicitToJson: true)
  const factory CharacterDto({
    required int id,
    required String name,
    required List<String> aliases,
    required String description,

    /// An ISO 8601 instant. Kept as text, not shown.
    required String modified,
    required ImageDto thumbnail,
    required List<String> powers,

    /// Stat name to 1..100.
    required Map<String, int> stats,
    required String team,
    required String origin,
    required int firstAppearanceYear,
    required AppearancesDto appearances,
  }) = _CharacterDto;

  factory CharacterDto.fromJson(Map<String, dynamic> json) =>
      _$CharacterDtoFromJson(json);
}

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class ImageDto with _$ImageDto {
  const factory ImageDto({required String path, required String variant}) =
      _ImageDto;

  factory ImageDto.fromJson(Map<String, dynamic> json) =>
      _$ImageDtoFromJson(json);
}

/// The counts of the character's appearances.
@Freezed(fromJson: true, toJson: true)
abstract class AppearancesDto with _$AppearancesDto {
  const factory AppearancesDto({
    required int comics,
    required int series,
    required int events,
  }) = _AppearancesDto;

  factory AppearancesDto.fromJson(Map<String, dynamic> json) =>
      _$AppearancesDtoFromJson(json);
}

/// `GET /v1/comics?characterId=`: a page of the comics that feature the
/// character.
@Freezed(fromJson: true, toJson: true)
abstract class ComicsPageDto with _$ComicsPageDto {
  @JsonSerializable(explicitToJson: true)
  const factory ComicsPageDto({
    required int offset,
    required int limit,
    required int total,
    required int count,
    required List<ComicSummaryDto> results,
  }) = _ComicsPageDto;

  factory ComicsPageDto.fromJson(Map<String, dynamic> json) =>
      _$ComicsPageDtoFromJson(json);
}

/// One comic of the page: what a card shows.
@Freezed(fromJson: true, toJson: true)
abstract class ComicSummaryDto with _$ComicSummaryDto {
  @JsonSerializable(explicitToJson: true)
  const factory ComicSummaryDto({
    required int id,
    required String title,
    required int issueNumber,
    required int seriesId,
    required String releaseDate,
    required ImageDto cover,
  }) = _ComicSummaryDto;

  factory ComicSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$ComicSummaryDtoFromJson(json);
}

/// `GET/PUT/DELETE /v1/me/favourites/character/:id`: the answer of a
/// favourite read or write.
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
