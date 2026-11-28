import 'package:characters_search/src/domain/model/character_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_media/mc_media.dart';

part 'character.freezed.dart';

/// A character as this feature shows it. Domain model: no JSON, so a bare
/// `@freezed` (R30 is about models with JSON); the wire shape is
/// `CharacterDto`.
@freezed
abstract class Character with _$Character {
  const factory Character({
    required CharacterId id,
    required String name,
    required ApiImage image,
  }) = _Character;
}
