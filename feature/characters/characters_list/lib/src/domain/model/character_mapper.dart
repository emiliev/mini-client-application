import 'package:characters_list/src/domain/model/character.dart';
import 'package:characters_list/src/domain/model/character_dto.dart';
import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:characters_list/src/domain/model/comic_id.dart';
import 'package:characters_list/src/domain/model/related_comic.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_paging/mc_paging.dart';

/// Wire to domain. An unknown variant name throws a `FormatException`, which
/// the repository's `apiCall` turns into `ApiMalformed`.
extension CharacterDtoMapper on CharacterDto {
  Character toDomain() =>
      Character(id: CharacterId(id), name: name, image: thumbnail.toDomain());
}

extension ThumbnailDtoMapper on ThumbnailDto {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}

extension RelatedComicDtoMapper on RelatedComicDto {
  RelatedComic toDomain() =>
      RelatedComic(id: ComicId(id), title: title, cover: cover.toDomain());
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
