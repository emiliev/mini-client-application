import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_dto.freezed.dart';
part 'search_dto.g.dart';

// The wire shapes this feature reads, as `mc_fixtures_discovery`'s
// CONTRACT.md defines them. The contract test pins each to the served JSON.
//
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// `GET /v1/search`: the results, one group per requested type, always in
/// the order `character`, `comic`.
@Freezed(fromJson: true, toJson: true)
abstract class SearchResponseDto with _$SearchResponseDto {
  @JsonSerializable(explicitToJson: true)
  const factory SearchResponseDto({
    /// `q` after trimming, as typed.
    required String query,
    required List<SearchGroupDto> groups,
  }) = _SearchResponseDto;

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SearchResponseDtoFromJson(json);
}

/// One type's matches: [total] counts all of them, [results] holds the first
/// `limit`.
@Freezed(fromJson: true, toJson: true)
abstract class SearchGroupDto with _$SearchGroupDto {
  @JsonSerializable(explicitToJson: true)
  const factory SearchGroupDto({
    /// `character` or `comic`.
    required String type,
    required int total,
    required List<SearchResultDto> results,
  }) = _SearchGroupDto;

  factory SearchGroupDto.fromJson(Map<String, dynamic> json) =>
      _$SearchGroupDtoFromJson(json);
}

/// One match. [id] is the id on its own domain's detail endpoint; the
/// [thumbnail] is the image that detail serves.
@Freezed(fromJson: true, toJson: true)
abstract class SearchResultDto with _$SearchResultDto {
  // `includeIfNull: false`: the contract leaves `subtitle` out when there is
  // none (a character without a team), so a served body round-trips.
  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory SearchResultDto({
    required int id,
    required String type,
    required String title,

    /// A character's team (absent when it has none), a comic's release year.
    String? subtitle,
    required SearchImageDto thumbnail,
  }) = _SearchResultDto;

  factory SearchResultDto.fromJson(Map<String, dynamic> json) =>
      _$SearchResultDtoFromJson(json);
}

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class SearchImageDto with _$SearchImageDto {
  const factory SearchImageDto({
    required String path,
    required String variant,
  }) = _SearchImageDto;

  factory SearchImageDto.fromJson(Map<String, dynamic> json) =>
      _$SearchImageDtoFromJson(json);
}
