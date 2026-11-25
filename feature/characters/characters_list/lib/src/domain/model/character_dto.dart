import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_dto.freezed.dart';
part 'character_dto.g.dart';

/// A character summary as `GET /v1/characters` sends it (CONTRACT.md of
/// `mc_fixtures_characters`). The contract test pins it to the fixture JSON.
///
/// The JSON flags are spelled out (R30): under the Bazel shim a bare
/// `@freezed` silently loses its JSON (F-0025).
@Freezed(fromJson: true, toJson: true)
abstract class CharacterDto with _$CharacterDto {
  @JsonSerializable(explicitToJson: true)
  const factory CharacterDto({
    required int id,
    required String name,
    required String description,
    required DateTime modified,
    required ThumbnailDto thumbnail,
  }) = _CharacterDto;

  factory CharacterDto.fromJson(Map<String, dynamic> json) =>
      _$CharacterDtoFromJson(json);
}

/// The `thumbnail` object: an image path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class ThumbnailDto with _$ThumbnailDto {
  const factory ThumbnailDto({required String path, required String variant}) =
      _ThumbnailDto;

  factory ThumbnailDto.fromJson(Map<String, dynamic> json) =>
      _$ThumbnailDtoFromJson(json);
}
