part of 'comic_details_bloc.dart';

/// What the details page asks for. Hand-written sealed events with private
/// cases (Tide), so a page can only create them through the factories.
sealed class ComicDetailsEvent {
  const ComicDetailsEvent();

  /// Loads the comic (again): the first load, and Retry after a failure.
  const factory ComicDetailsEvent.load() = _Load;

  /// The cover was tapped: it opens full size inside the flow.
  const factory ComicDetailsEvent.openCover() = _OpenCover;

  /// A character in the cast section was tapped.
  const factory ComicDetailsEvent.openCharacter(CharacterId id) =
      _OpenCharacter;

  /// A creator in the credits was tapped.
  const factory ComicDetailsEvent.openCreator(CreatorId id) = _OpenCreator;
}

final class _Load extends ComicDetailsEvent {
  const _Load();
}

final class _OpenCover extends ComicDetailsEvent {
  const _OpenCover();
}

final class _OpenCharacter extends ComicDetailsEvent {
  const _OpenCharacter(this.id);

  final CharacterId id;
}

final class _OpenCreator extends ComicDetailsEvent {
  const _OpenCreator(this.id);

  final CreatorId id;
}
