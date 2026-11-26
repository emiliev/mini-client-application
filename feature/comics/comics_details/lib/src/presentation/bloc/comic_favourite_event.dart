part of 'comic_favourite_bloc.dart';

/// What the favourite toggle asks for.
sealed class ComicFavouriteEvent {
  const ComicFavouriteEvent();

  /// Reads whether the comic is a favourite (signed in), or shows it as not
  /// one (signed out).
  const factory ComicFavouriteEvent.load() = _Load;

  /// The toggle was tapped (ignored while a sign-in or a write is in flight).
  const factory ComicFavouriteEvent.toggle() = _Toggle;
}

final class _Load extends ComicFavouriteEvent {
  const _Load();
}

final class _Toggle extends ComicFavouriteEvent {
  const _Toggle();
}

/// Internal: `SessionReader.authState` changed (a sign-in or a sign-out,
/// here or anywhere else in the app).
final class _SessionChanged extends ComicFavouriteEvent {
  const _SessionChanged();
}
