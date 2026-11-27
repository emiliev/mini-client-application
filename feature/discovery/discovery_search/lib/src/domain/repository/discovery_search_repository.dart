import 'package:discovery_search/src/domain/api/discovery_search_api.dart';
import 'package:discovery_search/src/domain/model/search_mapper.dart';
import 'package:discovery_search/src/domain/model/search_results.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// How many results of each type one search asks for: the first page of
/// every group. Paging further is a later feature (a "see all" page).
const int searchPageSize = 20;

/// The backend's answer for a query that is too short to search
/// (`mc_fixtures_discovery` CONTRACT.md, "Errors").
const String queryTooShortCode = 'query_too_short';

/// Search results as values, never exceptions. Stateless (Tide): which
/// query is on screen, and what was searched before, live in the bloc and in
/// the search history.
@injectable
class DiscoverySearchRepository {
  const DiscoverySearchRepository(this._api);

  final DiscoverySearchApi _api;

  /// The first [searchPageSize] matches of each type for [query], characters
  /// first.
  ///
  /// **Null** when the backend finds the query too short to search (a `400`
  /// whose error code is [queryTooShortCode]). The backend counts characters
  /// after folding accents away, so a query the client counts as long
  /// enough can still be too short ("e" plus a combining accent, two bare
  /// accents); the client does not copy the backend's fold table, it takes
  /// the backend's word.
  Future<Result<SearchResults?, ApiFailure>> search(String query) async {
    final result = await apiCall(
      () async => (await _api.search(query, limit: searchPageSize)).toDomain(),
    );
    return result.fold(
      success,
      (error) => error is ApiClientError && error.code == queryTooShortCode
          ? success(null)
          : failure(error),
    );
  }
}
