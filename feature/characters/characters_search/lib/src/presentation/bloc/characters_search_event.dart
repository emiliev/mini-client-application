part of 'characters_search_bloc.dart';

/// What the search page asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories; the
/// bloc's own events (the debounced search, the clear, the history load, a
/// page of results) have no factory.
sealed class CharactersSearchEvent {
  const CharactersSearchEvent();

  /// The field's text changed (every edit, the clear button included).
  const factory CharactersSearchEvent.queryChanged(String text) = _QueryChanged;

  /// A query to search at once: a tapped recent search, or the keyboard's
  /// Search key.
  const factory CharactersSearchEvent.submitted(String text) = _Submitted;

  /// A sort chip was chosen.
  const factory CharactersSearchEvent.sortChanged(CharacterSort sort) =
      _SortChanged;

  /// A team chip was chosen, or cleared (null: every team).
  const factory CharactersSearchEvent.teamChanged(String? team) = _TeamChanged;

  /// The results scrolled past their load-more threshold.
  const factory CharactersSearchEvent.loadMore() = _LoadMore;

  /// Retry after a failed request (the first page or a later one).
  const factory CharactersSearchEvent.retry() = _Retry;

  /// Pull to refresh: reloads the first page and keeps the results meanwhile.
  /// [done] completes when the reload settled, so the refresh control closes.
  const factory CharactersSearchEvent.refresh(Completer<void> done) = _Refresh;

  /// "Clear" above the recent searches.
  const factory CharactersSearchEvent.clearHistory() = _ClearHistory;

  /// A result was tapped.
  const factory CharactersSearchEvent.open(CharacterId id) = _Open;
}

final class _QueryChanged extends CharactersSearchEvent {
  const _QueryChanged(this.text);

  final String text;
}

final class _Submitted extends CharactersSearchEvent {
  const _Submitted(this.text);

  final String text;
}

final class _SortChanged extends CharactersSearchEvent {
  const _SortChanged(this.sort);

  final CharacterSort sort;
}

final class _TeamChanged extends CharactersSearchEvent {
  const _TeamChanged(this.team);

  final String? team;
}

final class _LoadMore extends CharactersSearchEvent {
  const _LoadMore();
}

final class _Retry extends CharactersSearchEvent {
  const _Retry();
}

final class _Refresh extends CharactersSearchEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _ClearHistory extends CharactersSearchEvent {
  const _ClearHistory();
}

final class _Open extends CharactersSearchEvent {
  const _Open(this.id);

  final CharacterId id;
}

/// Typing paused on [query] (from `DebouncedQuery`).
final class _Search extends CharactersSearchEvent {
  const _Search(this.query);

  final String query;
}

/// The field became empty after a search fired (from `DebouncedQuery`).
final class _Cleared extends CharactersSearchEvent {
  const _Cleared();
}

/// Reads the saved recent searches, once, when the bloc starts.
final class _LoadHistory extends CharactersSearchEvent {
  const _LoadHistory();
}

/// The paging controller of search [generation] produced a new state.
final class _PageChanged extends CharactersSearchEvent {
  const _PageChanged(this.generation, this.page);

  final int generation;
  final PagedState<Character> page;
}
