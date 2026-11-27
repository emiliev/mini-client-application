part of 'character_details_bloc.dart';

/// What the profile page asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class CharacterDetailsEvent {
  const CharacterDetailsEvent();

  /// Loads the character (again): the first load, and Retry after a failure.
  const factory CharacterDetailsEvent.load() = _Load;

  /// A comic in the "Comics" row was tapped.
  const factory CharacterDetailsEvent.openComic(ComicId id) = _OpenComic;
}

final class _Load extends CharacterDetailsEvent {
  const _Load();
}

final class _OpenComic extends CharacterDetailsEvent {
  const _OpenComic(this.id);

  final ComicId id;
}
