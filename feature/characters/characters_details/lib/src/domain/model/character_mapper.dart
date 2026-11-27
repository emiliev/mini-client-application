import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/domain/model/character_dto.dart';
import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/domain/model/comic_id.dart';
import 'package:mc_media/mc_media.dart';

/// Wire to domain. A value the contract does not allow (an unknown variant,
/// a missing or out-of-range stat) throws a [FormatException], which the
/// repository's `apiCall` turns into `ApiMalformed`.
extension CharacterDtoMapper on CharacterDto {
  Character toDomain() => Character(
    id: CharacterId(id),
    name: name,
    aliases: List.unmodifiable(aliases),
    bio: description,
    portrait: thumbnail.toDomain(),
    origin: origin,
    team: team,
    firstAppearanceYear: firstAppearanceYear,
    powers: List.unmodifiable(powers),
    stats: [
      for (final kind in StatKind.values)
        CharacterStat(kind: kind, value: _statValue(kind)),
    ],
  );

  int _statValue(StatKind kind) {
    final value = stats[kind.wireName];
    if (value == null) {
      throw FormatException('Missing stat "${kind.wireName}"');
    }
    if (value < 1 || value > 100) {
      throw FormatException('Stat "${kind.wireName}" out of range', value);
    }
    return value;
  }
}

extension ImageDtoMapper on ImageDto {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}

extension ComicSummaryDtoMapper on ComicSummaryDto {
  ComicSummary toDomain() =>
      ComicSummary(id: ComicId(id), title: title, cover: cover.toDomain());
}
