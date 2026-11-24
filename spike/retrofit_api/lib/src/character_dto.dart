import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_dto.freezed.dart';
part 'character_dto.g.dart';

/// A freezed + json transport model, as Tide's feature DTOs are.
///
/// `fromJson` / `toJson` are explicit: freezed detects json_serializable by a
/// source path starting with `/json_annotation/`, which holds under
/// build_runner but not under the Bazel shim, so a bare `@freezed` silently
/// loses its JSON there (F-0025).
@Freezed(fromJson: true, toJson: true)
abstract class CharacterDto with _$CharacterDto {
  const factory CharacterDto({
    required int id,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
  }) = _CharacterDto;

  factory CharacterDto.fromJson(Map<String, dynamic> json) =>
      _$CharacterDtoFromJson(json);
}
