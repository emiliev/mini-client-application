import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_discovery/src/search/normalize.dart';
import 'package:mc_media/mc_media.dart';

/// The domains a search covers, in the order its groups are served.
const List<String> searchTypes = ['character', 'comic'];

/// How well a title matches a query; the lower the index, the better.
enum MatchTier {
  /// The folded title equals the folded query.
  exact,

  /// The title starts with the query.
  prefix,

  /// The query starts a later word of the title.
  wordPrefix,

  /// The query occurs inside a word.
  substring,
}

/// One searchable item: a character or a comic.
final class SearchEntry {
  SearchEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.thumbnail,
    this.subtitle,
  }) : folded = foldText(title) {
    if (!searchTypes.contains(type)) {
      throw ArgumentError.value(
        type,
        'type',
        'must be one of ${searchTypes.join(', ')}',
      );
    }
  }

  final int id;
  final String type;
  final String title;
  final String? subtitle;
  final ApiImage thumbnail;

  /// [title] folded once, for matching.
  final String folded;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    'thumbnail': thumbnail.toJson(),
  };
}

/// A matched entry and how well it matched.
final class SearchMatch {
  const SearchMatch(this.entry, this.tier);

  final SearchEntry entry;
  final MatchTier tier;
}

final RegExp _notWordChar = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// The code point that ends right before [index] (a surrogate pair is one
/// character, not two code units).
String _runeBefore(String text, int index) {
  final unit = text.codeUnitAt(index - 1);
  final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
  if (isLow && index >= 2) {
    final high = text.codeUnitAt(index - 2);
    if (high >= 0xD800 && high <= 0xDBFF) {
      return text.substring(index - 2, index);
    }
  }
  return text[index - 1];
}

/// How [foldedTitle] matches [foldedQuery], or null when it does not. Both
/// arguments must come from [foldText].
MatchTier? matchTier(String foldedTitle, String foldedQuery) {
  if (foldedTitle == foldedQuery) {
    return MatchTier.exact;
  }
  if (foldedTitle.startsWith(foldedQuery)) {
    return MatchTier.prefix;
  }
  var at = foldedTitle.indexOf(foldedQuery);
  if (at < 0) {
    return null;
  }
  var tier = MatchTier.substring;
  while (at >= 0) {
    if (_notWordChar.hasMatch(_runeBefore(foldedTitle, at))) {
      tier = MatchTier.wordPrefix;
      break;
    }
    at = foldedTitle.indexOf(foldedQuery, at + 1);
  }
  return tier;
}

/// The total order of the ranking: tier, then title, then type (characters
/// before comics, so a cross-domain list is stable), then id.
int compareMatches(SearchMatch a, SearchMatch b) {
  final byTier = a.tier.index.compareTo(b.tier.index);
  if (byTier != 0) {
    return byTier;
  }
  final byTitle = a.entry.title.compareTo(b.entry.title);
  if (byTitle != 0) {
    return byTitle;
  }
  final byType = searchTypes
      .indexOf(a.entry.type)
      .compareTo(searchTypes.indexOf(b.entry.type));
  if (byType != 0) {
    return byType;
  }
  return a.entry.id.compareTo(b.entry.id);
}

/// A read-only index over characters and comics.
final class SearchIndex {
  SearchIndex(Iterable<SearchEntry> entries)
    : _entries = List.unmodifiable(entries);

  /// Every character and comic of the universes for [seed]. They are read
  /// through the other domains' public APIs, never copied.
  factory SearchIndex.fromUniverses(int seed, DateTime clock) {
    return SearchIndex([
      for (final c in CharacterUniverse(seed, clock).byName)
        SearchEntry(
          id: c.id,
          type: 'character',
          title: c.name,
          subtitle: c.team.isEmpty ? null : c.team,
          thumbnail: c.thumbnail,
        ),
      for (final c in ComicUniverse(seed).byTitle)
        SearchEntry(
          id: c.id,
          type: 'comic',
          title: c.title,
          subtitle: '${c.releaseDate.year}',
          thumbnail: c.cover,
        ),
    ]);
  }

  /// An index with nothing in it.
  static final SearchIndex empty = SearchIndex(const []);

  final List<SearchEntry> _entries;

  /// Every entry that matches [query] and is one of [types], ranked.
  List<SearchMatch> search(String query, {Iterable<String>? types}) {
    final folded = foldText(query);
    final wanted = types?.toSet();
    final matches = <SearchMatch>[];
    for (final entry in _entries) {
      if (wanted != null && !wanted.contains(entry.type)) {
        continue;
      }
      final tier = matchTier(entry.folded, folded);
      if (tier != null) {
        matches.add(SearchMatch(entry, tier));
      }
    }
    return matches..sort(compareMatches);
  }
}
