import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_dto.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_paging/mc_paging.dart';

/// Wire to domain. An unknown variant name throws a `FormatException`, which
/// the repository's `apiCall` turns into `ApiMalformed`.
extension CharacterDtoMapper on CharacterDto {
  Character toDomain() => Character(
    id: CharacterId(id),
    name: name,
    image: ApiImage(
      path: thumbnail.path,
      variant: ImageVariant.fromWire(thumbnail.variant),
    ),
  );
}

/// The envelope as the paging kit's [Page].
extension CharacterPageMapper on ApiPage<CharacterDto> {
  Page<Character> toDomain() => Page(
    offset: offset,
    limit: limit,
    total: total,
    results: [for (final dto in results) dto.toDomain()],
  );
}
