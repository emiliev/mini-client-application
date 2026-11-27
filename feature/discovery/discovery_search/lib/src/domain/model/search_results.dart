import 'package:discovery_search/src/domain/model/character_id.dart';
import 'package:discovery_search/src/domain/model/comic_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_media/mc_media.dart';

part 'search_results.freezed.dart';

/// What one search found, as the page shows it: a group per type, characters
/// first, each in the backend's ranking. Domain model: no JSON, so a bare
/// `@freezed` (R30 is about models with JSON); the wire shape is
/// `SearchResponseDto`.
@freezed
abstract class SearchResults with _$SearchResults {
  const SearchResults._();

  const factory SearchResults({
    /// The query the backend answered (trimmed, as typed).
    required String query,

    /// One group per type, in [SearchType] order.
    required List<SearchGroup> groups,
  }) = _SearchResults;

  /// True when no group has a match.
  bool get isEmpty => groups.every((group) => group.total == 0);
}

/// One type's matches: [total] counts every match, [hits] holds the first
/// page of them (the backend's `limit`).
@freezed
abstract class SearchGroup with _$SearchGroup {
  const factory SearchGroup({
    required SearchType type,
    required int total,
    required List<SearchHit> hits,
  }) = _SearchGroup;
}

/// One match: a character or a comic. A tap hands it over to the app, which
/// knows where each kind lives (`openCharacter`, `openComic`).
@freezed
sealed class SearchHit with _$SearchHit {
  const factory SearchHit.character({
    required CharacterId id,
    required String title,

    /// The character's team, when it has one.
    String? subtitle,
    required ApiImage image,
  }) = CharacterHit;

  const factory SearchHit.comic({
    required ComicId id,
    required String title,

    /// The comic's release year.
    String? subtitle,
    required ApiImage image,
  }) = ComicHit;
}

/// The kinds of result, in the order the backend groups them
/// (`mc_fixtures_discovery` CONTRACT.md).
enum SearchType {
  character('character'),
  comic('comic');

  const SearchType(this.wireName);

  /// The name on the wire.
  final String wireName;

  /// The type named [name]; an unknown name is a [FormatException], which
  /// the repository's `apiCall` turns into `ApiMalformed`.
  static SearchType fromWire(String name) => values.firstWhere(
    (type) => type.wireName == name,
    orElse: () => throw FormatException('Unknown result type "$name"'),
  );
}

/// The type chips: every group, or one type. Filtering is client-side: one
/// search answers both groups, so a chip changes what shows and sends no
/// request.
enum SearchFilter {
  all,
  characters,
  comics;

  /// Whether a group of [type] shows under this filter.
  bool shows(SearchType type) => switch (this) {
    all => true,
    characters => type == SearchType.character,
    comics => type == SearchType.comic,
  };

  /// The filter that shows only [type] ("Show 20" on a group).
  static SearchFilter only(SearchType type) => switch (type) {
    SearchType.character => characters,
    SearchType.comic => comics,
  };
}
