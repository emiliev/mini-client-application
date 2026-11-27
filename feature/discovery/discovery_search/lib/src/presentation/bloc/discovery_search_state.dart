part of 'discovery_search_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16); freezed 4
/// adds only `sealed`.
@freezed
sealed class DiscoverySearchState with _$DiscoverySearchState {
  /// Nothing is searched: the field is empty, or its text is too short. The
  /// recent searches show, most recent first. [clearFailed] when the last
  /// Clear could not remove them (they still show).
  const factory DiscoverySearchState.idle({
    required List<String> history,
    @Default(false) bool clearFailed,
  }) = _Idle;

  /// [query]'s request is in flight.
  const factory DiscoverySearchState.searching({required String query}) =
      _Searching;

  /// [query] found something. [filter] picks the groups that show; the
  /// results always hold both.
  const factory DiscoverySearchState.results({
    required String query,
    required SearchResults results,
    required SearchFilter filter,
  }) = _Results;

  /// [query] found nothing in any group. Not a failure: nothing to retry.
  const factory DiscoverySearchState.empty({required String query}) = _Empty;

  /// [query]'s request failed; Retry searches it again. `McBloc` reports it
  /// to monitoring (D-16).
  @Implements<McFailureState>()
  const factory DiscoverySearchState.failure({
    required String query,
    required ApiFailure error,
    StackTrace? stackTrace,
  }) = _Failure;
}
