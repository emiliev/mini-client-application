import 'package:comics_details/src/domain/api/comics_details_api.dart';
import 'package:comics_details/src/domain/model/comic.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/domain/model/comic_mapper.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// The comic and its favourite flag as values, never exceptions. Stateless
/// (Tide): what the page shows lives in its blocs and the flow state.
@injectable
class ComicsDetailsRepository {
  const ComicsDetailsRepository(this._api);

  final ComicsDetailsApi _api;

  /// The comic with its cast, in one request: the detail carries the cast
  /// summary (T-0041), so there is no request per character. An unknown
  /// comic is [ApiNotFound].
  Future<Result<Comic, ApiFailure>> fetchComic(ComicId id) =>
      apiCall(() async => (await _api.getComic(id.value)).toDomain());

  /// Whether the signed-in user has the comic among their favourites. The
  /// backend answers `404` for "not a favourite".
  Future<Result<bool, ApiFailure>> isFavourite(ComicId id) => apiCall(
    () async =>
        await _orNullWhenNotFound(
          () async => (await _api.getFavourite(id.value)).favourite,
        ) ??
        false,
  );

  /// Writes the flag and returns what the backend now holds.
  Future<Result<bool, ApiFailure>> setFavourite(
    ComicId id, {
    required bool favourite,
  }) => apiCall(
    () async =>
        (favourite
                ? await _api.putFavourite(id.value)
                : await _api.deleteFavourite(id.value))
            .favourite,
  );

  static Future<T?> _orNullWhenNotFound<T extends Object>(
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
