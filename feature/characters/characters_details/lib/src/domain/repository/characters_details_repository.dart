import 'package:characters_details/src/domain/api/characters_details_api.dart';
import 'package:characters_details/src/domain/model/character.dart';
import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/domain/model/character_mapper.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// The character and its favourite flag as values, never exceptions. Stateless
/// (Tide): what the page shows lives in its blocs and the flow state.
@injectable
class CharacterDetailsRepository {
  const CharacterDetailsRepository(this._api);

  final CharacterDetailsApi _api;

  /// How many comics the "Comics" row asks for: one page of the comics
  /// domain's reverse lookup.
  static const int comicsLimit = 20;

  /// The character in detail. An unknown character is [ApiNotFound].
  Future<Result<Character, ApiFailure>> fetchCharacter(CharacterId id) =>
      apiCall(() async => (await _api.getCharacter(id.value)).toDomain());

  /// The comics the character appears in, in title order (at most
  /// [comicsLimit]). A character nobody features has none.
  Future<Result<List<ComicSummary>, ApiFailure>> fetchComics(CharacterId id) =>
      apiCall(() async {
        final page = await _api.getComics(id.value, comicsLimit);
        return [for (final comic in page.results) comic.toDomain()];
      });

  /// Whether the signed-in user has the character among their favourites. The
  /// backend answers `404` for "not a favourite".
  Future<Result<bool, ApiFailure>> isFavourite(CharacterId id) => apiCall(
    () async =>
        await _orNullWhenNotFound(
          () async => (await _api.getFavourite(id.value)).favourite,
        ) ??
        false,
  );

  /// Writes the flag and returns what the backend now holds. The request is
  /// pinned to the session [epoch] the caller's own check used (the session its
  /// shown state belongs to): if the session changed
  /// before it was sent, nothing is sent and the answer is
  /// [ApiUnauthorized] (T-0050), so a write never goes out under another
  /// user's bearer.
  Future<Result<bool, ApiFailure>> setFavourite(
    CharacterId id, {
    required bool favourite,
    required int epoch,
  }) => apiCall(
    () async =>
        (favourite
                ? await _api.putFavourite(id.value, extras: authPinned(epoch))
                : await _api.deleteFavourite(
                    id.value,
                    extras: authPinned(epoch),
                  ))
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
