/// Visibility values the API accepts.
const List<String> visibilities = ['private', 'public'];

const int nameMinLength = 1;
const int nameMaxLength = 60;
const int descriptionMaxLength = 280;
const int maxComicsPerList = 100;

/// One reading list. Mutable: the handlers edit it in the backend's store.
final class ReadingList {
  ReadingList({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.comicIds,
    required this.updatedAt,
  });

  final String id;
  String name;
  String description;
  String visibility;
  List<int> comicIds;
  DateTime updatedAt;

  /// The list shape (`GET /v1/me/lists`).
  Map<String, Object?> toSummaryJson() => {
    'id': id,
    'name': name,
    'description': description,
    'visibility': visibility,
    'itemCount': comicIds.length,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// What the store keeps for one backend: every user's lists, the next list
/// number and a write counter that orders `updatedAt`.
final class LibraryState {
  LibraryState(this.listsByUser, this.nextNumber);

  final Map<String, List<ReadingList>> listsByUser;
  int nextNumber;
  int ticks = 0;
}
