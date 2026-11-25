part of 'characters_list_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16); freezed 4
/// adds only `sealed`.
@freezed
sealed class CharactersListState with _$CharactersListState {
  /// The first page is on its way.
  const factory CharactersListState.loading() = _Loading;

  /// Something to show: items (perhaps loading or failing more), or a
  /// settled empty list.
  const factory CharactersListState.success(PagedState<Character> page) =
      _Success;

  /// The first page failed. `McBloc` reports it to monitoring (D-16).
  @Implements<McFailureState>()
  const factory CharactersListState.failure(
    ApiFailure error, {
    StackTrace? stackTrace,
  }) = _Failure;
}
