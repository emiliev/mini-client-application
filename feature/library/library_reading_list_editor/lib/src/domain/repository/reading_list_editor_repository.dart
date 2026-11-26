import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/domain/api/reading_list_editor_api.dart';
import 'package:library_reading_list_editor/src/domain/model/comic_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_mapper.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// How many comics the picker shows per search.
const int comicSearchLimit = 20;

/// Reading lists and the comic search as values, never exceptions. Stateless
/// (Tide): what the editor shows lives in its blocs and the flow state.
///
/// A write the backend refuses is an `ApiClientError` whose `code` and
/// `parameter` come from the error body (`mc_api_errors`), so the editor can
/// show it under the field it names.
@injectable
class ReadingListEditorRepository {
  const ReadingListEditorRepository(this._api);

  final ReadingListEditorApi _api;

  /// One list of the signed-in user. Another user's list and an unknown id
  /// are both [ApiNotFound] (the contract never leaks ids).
  Future<Result<ReadingList, ApiFailure>> fetchList(ReadingListId id) =>
      apiCall(() async => (await _api.getList(id.value)).toDomain());

  /// Creates a list; the answer is the list as saved, with its new id.
  Future<Result<ReadingList, ApiFailure>> create(ReadingListDraft draft) =>
      apiCall(
        () async => (await _api.createList(draft.toCreateDto())).toDomain(),
      );

  /// Writes the name, description and visibility.
  Future<Result<ReadingList, ApiFailure>> updateDetails(
    ReadingListId id,
    ReadingListDraft draft,
  ) => apiCall(
    () async =>
        (await _api.updateList(id.value, draft.toDetailsDto())).toDomain(),
  );

  /// Writes the comics, in [draft]'s order.
  Future<Result<ReadingList, ApiFailure>> replaceItems(
    ReadingListId id,
    ReadingListDraft draft,
  ) => apiCall(
    () async =>
        (await _api.replaceItems(id.value, draft.toItemsDto())).toDomain(),
  );

  /// Comics whose title starts with [query] (all comics for an empty one),
  /// in title order, at most [comicSearchLimit].
  Future<Result<List<PickedComic>, ApiFailure>> searchComics(String query) =>
      apiCall(() async {
        final page = await _api.searchComics(
          titleStartsWith: query.isEmpty ? null : query,
          limit: comicSearchLimit,
        );
        return [for (final hit in page.results) hit.toDomain()];
      });
}

/// The ids of [comics], in order.
List<ComicId> comicIdsOf(List<PickedComic> comics) => [
  for (final comic in comics) comic.id,
];
