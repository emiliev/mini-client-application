import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:library_reading_list_editor/src/domain/model/comic_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:mc_media/mc_media.dart';

part 'reading_list.freezed.dart';

/// Who can see a list. The wire names are the contract's
/// (`mc_fixtures_library` CONTRACT.md).
enum ReadingListVisibility {
  private('private'),
  public('public');

  const ReadingListVisibility(this.wireName);

  /// The name in JSON.
  final String wireName;

  /// A value the contract does not allow throws a [FormatException], which
  /// the repository turns into `ApiMalformed`.
  static ReadingListVisibility fromWire(String name) => values.firstWhere(
    (v) => v.wireName == name,
    orElse: () => throw FormatException('Unknown visibility', name),
  );
}

/// A comic as the editor shows it: picked in step 2, ordered in step 3. The
/// search results and a loaded list's items both map to it.
@freezed
abstract class PickedComic with _$PickedComic {
  const factory PickedComic({
    required ComicId id,
    required String title,
    required ApiImage cover,
  }) = _PickedComic;
}

/// A saved list, as the backend holds it after a read or a write: the
/// baseline an edit is compared with, so only the parts that changed are
/// sent (T-0048-AC3).
@freezed
abstract class ReadingList with _$ReadingList {
  const factory ReadingList({
    required ReadingListId id,
    required String name,
    required String description,
    required ReadingListVisibility visibility,
    required List<PickedComic> comics,
  }) = _ReadingList;
}

/// What the user asks to save: the wizard's values, ready for the wire (the
/// name trimmed, as the backend stores it).
@freezed
abstract class ReadingListDraft with _$ReadingListDraft {
  const factory ReadingListDraft({
    required String name,
    required String description,
    required ReadingListVisibility visibility,
    required List<ComicId> comicIds,
  }) = _ReadingListDraft;

  const ReadingListDraft._();

  /// The name, description or visibility differ from [saved]'s.
  bool detailsDifferFrom(ReadingList saved) =>
      name != saved.name ||
      description != saved.description ||
      visibility != saved.visibility;

  /// The comics or their order differ from [saved]'s.
  bool itemsDifferFrom(ReadingList saved) {
    final savedIds = [for (final c in saved.comics) c.id];
    if (comicIds.length != savedIds.length) {
      return true;
    }
    for (var i = 0; i < comicIds.length; i++) {
      if (comicIds[i] != savedIds[i]) {
        return true;
      }
    }
    return false;
  }
}
