import 'package:discovery_search/src/domain/model/character_id.dart';
import 'package:discovery_search/src/domain/model/comic_id.dart';
import 'package:discovery_search/src/domain/model/search_dto.dart';
import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:mc_media/mc_media.dart';

/// Wire to domain. A value the contract does not allow (an unknown result
/// type or image variant, a result in the wrong group, groups other than
/// exactly `character` then `comic`) throws a [FormatException], which the
/// repository's `apiCall` turns into `ApiMalformed`.
extension SearchResponseDtoMapper on SearchResponseDto {
  SearchResults toDomain() {
    final mapped = [for (final group in groups) group.toDomain()];
    final types = [for (final group in mapped) group.type];
    // The feature asks for every type, so the contract answers one group
    // per type, always in [SearchType] order.
    const expected = SearchType.values;
    final inOrder =
        types.length == expected.length &&
        types.indexed.every((e) => e.$2 == expected[e.$1]);
    if (!inOrder) {
      throw FormatException(
        'Expected the groups ${SearchType.values.map((t) => t.wireName)}, '
        'got ${types.map((t) => t.wireName)}',
      );
    }
    return SearchResults(query: query, groups: mapped);
  }
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
