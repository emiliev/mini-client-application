import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/domain/api/reading_list_editor_api.dart';
import 'package:library_reading_list_editor/src/domain/model/comic_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_dto.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_mapper.dart';
import 'package:library_reading_list_editor/src/domain/model/save_failure.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// How many comics the picker shows per search.
const int comicSearchLimit = 20;

/// Reading lists and the comic search as values, never exceptions. Stateless
/// (Tide): what the editor shows lives in its blocs and the flow state.
@injectable
class ReadingListEditorRepository {
  const ReadingListEditorRepository(this._api);

  final ReadingListEditorApi _api;

  /// One list of the signed-in user. Another user's list and an unknown id
  /// are both [ApiNotFound] (the contract never leaks ids).
  Future<Result<ReadingList, ApiFailure>> fetchList(ReadingListId id) =>
      apiCall(() async => (await _api.getList(id.value)).toDomain());

  /// Creates a list; the answer is the list as saved, with its new id.
  Future<Result<ReadingList, SaveFailure>> create(ReadingListDraft draft) =>
      _save(() => _api.createList(draft.toCreateDto()));

  /// Writes the name, description and visibility.
  Future<Result<ReadingList, SaveFailure>> updateDetails(
    ReadingListId id,
    ReadingListDraft draft,
  ) => _save(() => _api.updateList(id.value, draft.toDetailsDto()));

  /// Writes the comics, in [draft]'s order.
  Future<Result<ReadingList, SaveFailure>> replaceItems(
    ReadingListId id,
    ReadingListDraft draft,
  ) => _save(() => _api.replaceItems(id.value, draft.toItemsDto()));

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

  static Future<Result<ReadingList, SaveFailure>> _save(
    Future<ReadingListDto> Function() call,
  ) => Result.guard(
    () async => (await call()).toDomain(),
    (error) => _rejection(error) ?? SaveApiFailure(ApiFailure.from(error)),
  );

  /// A `400` that names a field of the editor (CONTRACT.md "Validation"), or
  /// null for anything else.
  static SaveRejected? _rejection(Object error) {
    if (error is! DioException || error.response?.statusCode != 400) {
      return null;
    }
    final data = error.response?.data;
    if (data is! Map<String, dynamic>) {
      return null;
    }
    try {
      final body = ApiErrorBodyDto.fromJson(data).error;
      final field = ListField.fromWire(body.parameter);
      return field == null ? null : SaveRejected(field: field, code: body.code);
    } on Object {
      // Not the contract's error shape: an ordinary client error.
      return null;
    }
  }
}

/// The ids of [comics], in order.
List<ComicId> comicIdsOf(List<PickedComic> comics) => [
  for (final comic in comics) comic.id,
];
