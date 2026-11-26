part of 'discovery_search_bloc.dart';

/// What the search page asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories; the
/// bloc's own events (the debounced search, the clear, the history load)
/// have no factory.
sealed class DiscoverySearchEvent {
  const DiscoverySearchEvent();

  /// The field's text changed (every edit, the clear button included).
  const factory DiscoverySearchEvent.queryChanged(String text) = _QueryChanged;

  /// A query to search at once, not typed: a tapped recent search.
  const factory DiscoverySearchEvent.submitted(String text) = _Submitted;

  /// A type chip was chosen (or a group's "Show 20").
  const factory DiscoverySearchEvent.filterChanged(SearchFilter filter) =
      _FilterChanged;

  /// Retry after a failed search: the same query again.
  const factory DiscoverySearchEvent.retry() = _Retry;

  /// "Clear" above the recent searches.
  const factory DiscoverySearchEvent.clearHistory() = _ClearHistory;

  /// A result was tapped.
  const factory DiscoverySearchEvent.open(SearchHit hit) = _Open;
}

final class _QueryChanged extends DiscoverySearchEvent {
  const _QueryChanged(this.text);

  final String text;
}

final class _Submitted extends DiscoverySearchEvent {
  const _Submitted(this.text);

  final String text;
}

final class _FilterChanged extends DiscoverySearchEvent {
  const _FilterChanged(this.filter);

  final SearchFilter filter;
}

final class _Retry extends DiscoverySearchEvent {
  const _Retry();
}

final class _ClearHistory extends DiscoverySearchEvent {
  const _ClearHistory();
}

final class _Open extends DiscoverySearchEvent {
  const _Open(this.hit);

  final SearchHit hit;
}

/// Typing paused on [query] (from `DebouncedQuery`).
final class _Search extends DiscoverySearchEvent {
  const _Search(this.query);

  final String query;
}

/// The field became empty after a search fired (from `DebouncedQuery`).
final class _Cleared extends DiscoverySearchEvent {
  const _Cleared();
}

/// Reads the saved recent searches, once, when the bloc starts.
final class _LoadHistory extends DiscoverySearchEvent {
  const _LoadHistory();
}
