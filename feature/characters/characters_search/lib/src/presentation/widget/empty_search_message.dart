import 'package:characters_search/src/l10n/characters_search_l10n.dart';

/// What the empty view says when nothing matched [query]: it names the team
/// when one is chosen. Shared by the `empty` state and the paged list's own
/// empty view, so both follow the team facet.
String emptySearchMessage(
  CharactersSearchL10n l10n,
  String query,
  String? team,
) => switch (team) {
  final team? => l10n.charactersSearchEmptyTeamMessage(query, team),
  null => l10n.charactersSearchEmptyMessage(query),
};
