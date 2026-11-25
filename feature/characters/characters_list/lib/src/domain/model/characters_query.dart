/// What the list asks the backend for: one page, optionally of one team.
final class CharactersQuery {
  const CharactersQuery({
    required this.offset,
    required this.limit,
    this.teamId,
  });

  final int offset;
  final int limit;

  /// Null: every team.
  final String? teamId;
}
