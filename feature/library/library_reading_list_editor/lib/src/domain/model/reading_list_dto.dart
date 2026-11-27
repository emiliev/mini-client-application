import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_list_dto.freezed.dart';
part 'reading_list_dto.g.dart';

// The wire shapes this feature reads and writes, as the CONTRACT.md files of
// `mc_fixtures_library` and `mc_fixtures_comics` define them. The contract
// test pins each to the served JSON.
//
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// `GET /v1/me/lists/:id`, and the answer to every write: one list with its
/// items. Every field of the contract is here, so a served body round-trips
/// byte for byte; the domain keeps less.
@Freezed(fromJson: true, toJson: true)
abstract class ReadingListDto with _$ReadingListDto {
  @JsonSerializable(explicitToJson: true)
  const factory ReadingListDto({
    required String id,
    required String name,

    /// Always a string (`""` when there is none).
    required String description,

    /// `private` or `public`.
    required String visibility,
    required int itemCount,

    /// An ISO-8601 instant, kept as text so it round-trips.
    required String updatedAt,

    /// The comics in the stored order.
    required List<ReadingListItemDto> items,
  }) = _ReadingListDto;

  factory ReadingListDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingListDtoFromJson(json);
}

/// One comic of a list: its id, title and thumbnail, as
/// `GET /v1/comics/:id` serves them.
@Freezed(fromJson: true, toJson: true)
abstract class ReadingListItemDto with _$ReadingListItemDto {
  @JsonSerializable(explicitToJson: true)
  const factory ReadingListItemDto({
    required int id,
    required String title,
    required ImageDto thumbnail,
  }) = _ReadingListItemDto;

  factory ReadingListItemDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingListItemDtoFromJson(json);
}

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class ImageDto with _$ImageDto {
  const factory ImageDto({required String path, required String variant}) =
      _ImageDto;

  factory ImageDto.fromJson(Map<String, dynamic> json) =>
      _$ImageDtoFromJson(json);
}

/// `POST /v1/me/lists`: a new list with its comics, in order.
@Freezed(fromJson: true, toJson: true)
abstract class CreateReadingListDto with _$CreateReadingListDto {
  const factory CreateReadingListDto({
    required String name,
    required String description,
    required String visibility,
    required List<int> comicIds,
  }) = _CreateReadingListDto;

  factory CreateReadingListDto.fromJson(Map<String, dynamic> json) =>
      _$CreateReadingListDtoFromJson(json);
}

/// `PUT /v1/me/lists/:id`: the name, description and visibility. The items
/// are untouched.
@Freezed(fromJson: true, toJson: true)
abstract class ReadingListDetailsDto with _$ReadingListDetailsDto {
  const factory ReadingListDetailsDto({
    required String name,
    required String description,
    required String visibility,
  }) = _ReadingListDetailsDto;

  factory ReadingListDetailsDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingListDetailsDtoFromJson(json);
}

/// `PUT /v1/me/lists/:id/items`: the items become exactly these, in order.
@Freezed(fromJson: true, toJson: true)
abstract class ReadingListItemsDto with _$ReadingListItemsDto {
  const factory ReadingListItemsDto({required List<int> comicIds}) =
      _ReadingListItemsDto;

  factory ReadingListItemsDto.fromJson(Map<String, dynamic> json) =>
      _$ReadingListItemsDtoFromJson(json);
}

/// One result of `GET /v1/comics` (the picker's search): a comic summary.
@Freezed(fromJson: true, toJson: true)
abstract class ComicHitDto with _$ComicHitDto {
  @JsonSerializable(explicitToJson: true)
  const factory ComicHitDto({
    required int id,
    required String title,
    required int issueNumber,
    required int seriesId,

    /// A `YYYY-MM-DD` day, kept as text so it round-trips.
    required String releaseDate,
    required ImageDto cover,
  }) = _ComicHitDto;

  factory ComicHitDto.fromJson(Map<String, dynamic> json) =>
      _$ComicHitDtoFromJson(json);
}
