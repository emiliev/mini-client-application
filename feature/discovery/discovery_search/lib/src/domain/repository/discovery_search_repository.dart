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

/// Search results as values, never exceptions. Stateless (Tide): which
/// query is on screen, and what was searched before, live in the bloc and in
/// the search history.
@injectable
class DiscoverySearchRepository {
  const DiscoverySearchRepository(this._api);

  final DiscoverySearchApi _api;

  /// The first [searchPageSize] matches of each type for [query], characters
  /// first. A query the backend rejects (`400`) is an `ApiClientError`.
  Future<Result<SearchResults, ApiFailure>> search(String query) => apiCall(
    () async => (await _api.search(query, limit: searchPageSize)).toDomain(),
  );
}
