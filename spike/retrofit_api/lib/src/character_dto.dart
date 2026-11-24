import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_dto.freezed.dart';
part 'character_dto.g.dart';

/// A freezed + json transport model, as Tide's feature DTOs are.
@freezed
abstract class CharacterDto with _$CharacterDto {
  const factory CharacterDto({
    required int id,
    required String name,
    @Default('') String description,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
  }) = _CharacterDto;

  factory CharacterDto.fromJson(Map<String, dynamic> json) => _$CharacterDtoFromJson(json);
}
