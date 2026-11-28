/// The orders the backend sorts characters in (`orderBy`, CONTRACT.md of
/// `mc_fixtures_characters`); the list always ends on the id, so each is
/// total.
enum CharacterSort {
  /// Name, A to Z (the backend's default).
  nameAscending('name'),

  /// Name, Z to A.
  nameDescending('-name'),

  /// Most recently modified first.
  newest('-modified'),

  /// Least recently modified first.
  oldest('modified');

  const CharacterSort(this.wireName);

  /// The `orderBy` value.
  final String wireName;
}

/// The teams a character can be filtered by (`team`, CONTRACT.md of
/// `mc_fixtures_characters`, "Test-facing facts"). Proper names, not
/// translated; the backend matches them exactly, ignoring case.
const List<String> characterTeams = [
  'The Lantern Circle',
  'Harbor Watch',
  'Northern Compass',
  'The Quiet Ones',
  'Copper Street Collective',
  'Skyline Guild',
  'The Undertow',
  'Open Road',
];

/// What narrows and orders a search besides the typed prefix. A change of
/// either sends one new request from the first page.
final class CharacterFacets {
  const CharacterFacets({this.sort = CharacterSort.nameAscending, this.team});

  final CharacterSort sort;

  /// Null: every team.
  final String? team;

  CharacterFacets withSort(CharacterSort sort) =>
      CharacterFacets(sort: sort, team: team);

  CharacterFacets withTeam(String? team) =>
      CharacterFacets(sort: sort, team: team);

  @override
  bool operator ==(Object other) =>
      other is CharacterFacets && other.sort == sort && other.team == team;

  @override
  int get hashCode => Object.hash(sort, team);

  @override
  String toString() => 'CharacterFacets(sort: $sort, team: $team)';
}

/// What the search asks the backend for: one page of the characters whose
/// name starts with [prefix], narrowed and ordered by [facets].
final class CharactersSearchQuery {
  const CharactersSearchQuery({
    required this.prefix,
    required this.facets,
    required this.offset,
    required this.limit,
  });

  final String prefix;
  final CharacterFacets facets;
  final int offset;
  final int limit;
}
