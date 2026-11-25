part of 'characters_list_bloc.dart';

/// What the list page asks for. Hand-written sealed events with private cases
/// (Tide), so a page can only create them through the factories.
sealed class CharactersListEvent {
  const CharactersListEvent();

  /// Starts over with the first page.
  const factory CharactersListEvent.load() = _Load;

  /// The grid scrolled past its load-more threshold.
  const factory CharactersListEvent.loadMore() = _LoadMore;

  /// Repeats the request that failed (first page or a later one).
  const factory CharactersListEvent.retry() = _Retry;

  /// Pull to refresh: reloads the first page and keeps the items meanwhile.
  /// [done] completes when the reload settled, so the refresh control closes.
  const factory CharactersListEvent.refresh(Completer<void> done) = _Refresh;

  /// A tile was tapped: its preview opens inside the flow (ignored while a
  /// preview is open).
  const factory CharactersListEvent.preview(Character character) = _Preview;
}

final class _Load extends CharactersListEvent {
  const _Load();
}

final class _LoadMore extends CharactersListEvent {
  const _LoadMore();
}

final class _Retry extends CharactersListEvent {
  const _Retry();
}

final class _Refresh extends CharactersListEvent {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Preview extends CharactersListEvent {
  const _Preview(this.character);

  final Character character;
}

/// Internal: the paging controller produced a new state.
final class _PageChanged extends CharactersListEvent {
  const _PageChanged(this.page);

  final PagedState<Character> page;
}
