part of 'characters_search_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16); freezed 4
/// adds only `sealed`.
@freezed
sealed class CharactersSearchState with _$CharactersSearchState {
  /// Nothing is searched: the field is empty. The recent searches show, most
  /// recent first. [clearFailed] when the last Clear could not remove them
  /// (they still show).
  const factory CharactersSearchState.idle({
    required List<String> history,
    @Default(false) bool clearFailed,
  }) = _Idle;

  /// [query]'s first page is on its way.
  const factory CharactersSearchState.searching({
    required String query,
    required CharacterFacets facets,
  }) = _Searching;

  /// [query] found characters: the pages loaded so far (a later page may be
  /// loading or failing: [PagedState.isLoadingMore], [PagedState.failure]).
  const factory CharactersSearchState.results({
    required String query,
    required PagedState<Character> page,
    required CharacterFacets facets,
  }) = _Results;

  /// [query] with [facets] found nothing. Not a failure: nothing to retry.
  const factory CharactersSearchState.empty({
    required String query,
    required CharacterFacets facets,
  }) = _Empty;

  /// [query]'s first page failed; Retry asks for it again. `McBloc` reports
  /// it to monitoring (D-16).
  @Implements<McFailureState>()
  const factory CharactersSearchState.failure({
    required String query,
    required CharacterFacets facets,
    required ApiFailure error,
    StackTrace? stackTrace,
  }) = _Failure;
}
