import 'package:library_reading_list_editor/src/domain/model/comic_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_dto.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:mc_media/mc_media.dart';

/// Wire to domain and back. A value the contract does not allow (an unknown
/// visibility or image variant) throws a [FormatException], which the
/// repository turns into `ApiMalformed`.
extension ReadingListDtoMapper on ReadingListDto {
  ReadingList toDomain() => ReadingList(
    id: ReadingListId(id),
    name: name,
    description: description,
    visibility: ReadingListVisibility.fromWire(visibility),
    comics: [
      for (final item in items)
        PickedComic(
          id: ComicId(item.id),
          title: item.title,
          cover: item.thumbnail.toDomain(),
        ),
    ],
  );
}

extension ComicHitDtoMapper on ComicHitDto {
  PickedComic toDomain() =>
      PickedComic(id: ComicId(id), title: title, cover: cover.toDomain());
}

extension ImageDtoMapper on ImageDto {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}

extension ReadingListDraftMapper on ReadingListDraft {
  CreateReadingListDto toCreateDto() => CreateReadingListDto(
    name: name,
    description: description,
    visibility: visibility.wireName,
    comicIds: _ids,
  );

  ReadingListDetailsDto toDetailsDto() => ReadingListDetailsDto(
    name: name,
    description: description,
    visibility: visibility.wireName,
  );

  ReadingListItemsDto toItemsDto() => ReadingListItemsDto(comicIds: _ids);

  List<int> get _ids => [for (final id in comicIds) id.value];
}
