import 'package:discovery_search/src/domain/model/character_id.dart';
import 'package:discovery_search/src/domain/model/comic_id.dart';
import 'package:discovery_search/src/domain/model/search_dto.dart';
import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:mc_media/mc_media.dart';

/// Wire to domain. A value the contract does not allow (an unknown result
/// type or image variant, a result in the wrong group) throws a
/// [FormatException], which the repository's `apiCall` turns into
/// `ApiMalformed`.
extension SearchResponseDtoMapper on SearchResponseDto {
  SearchResults toDomain() => SearchResults(
    query: query,
    groups: [for (final group in groups) group.toDomain()],
  );
}

extension SearchGroupDtoMapper on SearchGroupDto {
  SearchGroup toDomain() {
    final groupType = SearchType.fromWire(type);
    return SearchGroup(
      type: groupType,
      total: total,
      hits: [
        for (final result in results)
          result.type == groupType.wireName
              ? result.toDomain()
              : throw FormatException(
                  'A ${result.type} result in the $type group',
                ),
      ],
    );
  }
}

extension SearchResultDtoMapper on SearchResultDto {
  SearchHit toDomain() {
    final image = thumbnail.toDomain();
    return switch (SearchType.fromWire(type)) {
      SearchType.character => SearchHit.character(
        id: CharacterId(id),
        title: title,
        subtitle: subtitle,
        image: image,
      ),
      SearchType.comic => SearchHit.comic(
        id: ComicId(id),
        title: title,
        subtitle: subtitle,
        image: image,
      ),
    };
  }
}

extension SearchImageDtoMapper on SearchImageDto {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}
