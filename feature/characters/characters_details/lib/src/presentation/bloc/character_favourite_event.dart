part of 'character_favourite_bloc.dart';

/// What the favourite toggle asks for.
sealed class CharacterFavouriteEvent {
  const CharacterFavouriteEvent();

  /// Reads whether the character is a favourite (signed in), or shows it as not
  /// one (signed out).
  const factory CharacterFavouriteEvent.load() = _Load;

  /// The toggle was tapped (ignored while a sign-in or a write is in flight).
  const factory CharacterFavouriteEvent.toggle() = _Toggle;
}

final class _Load extends CharacterFavouriteEvent {
  const _Load();
}

final class _Toggle extends CharacterFavouriteEvent {
  const _Toggle();
}

/// Internal: `SessionReader.authState` changed (a sign-in or a sign-out,
/// here or anywhere else in the app).
final class _SessionChanged extends CharacterFavouriteEvent {
  const _SessionChanged();
}

/// Internal: someone else announced `DataChanged('favourites')` on the bus.
final class _FavouritesChanged extends CharacterFavouriteEvent {
  const _FavouritesChanged();
}
