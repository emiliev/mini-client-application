part of 'comic_picker_bloc.dart';

/// Tide's state shape: private cases read with `state.when` (R16).
@freezed
sealed class ComicPickerState with _$ComicPickerState {
  /// Searching for [query] (empty: all comics).
  const factory ComicPickerState.loading({required String query}) = _Loading;

  /// The comics that match [query], in title order.
  const factory ComicPickerState.results({
    required String query,
    required List<PickedComic> comics,
  }) = _Results;

  /// No comic matches [query].
  const factory ComicPickerState.empty({required String query}) = _Empty;

  /// The search for [query] failed. `McBloc` reports it to monitoring.
  @Implements<McFailureState>()
  const factory ComicPickerState.failure(
    ApiFailure error, {
    required String query,
    StackTrace? stackTrace,
  }) = _Failure;
}
