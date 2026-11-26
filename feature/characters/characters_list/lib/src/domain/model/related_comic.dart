import 'package:characters_list/src/domain/model/comic_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_media/mc_media.dart';

part 'related_comic.freezed.dart';

/// A comic the previewed character appears in, as the preview lists it.
/// Domain model: no JSON (the wire shape is `RelatedComicDto`).
@freezed
abstract class RelatedComic with _$RelatedComic {
  const factory RelatedComic({
    required ComicId id,
    required String title,
    required ApiImage cover,
  }) = _RelatedComic;
}
