import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_paging/mc_paging.dart';

part 'holder_state.freezed.dart';

/// A bloc state shaped like `characters_list`'s: a freezed union whose case
/// holds a [PagedState], with freezed's default `copyWith` (no
/// `@Freezed(copyWith: false)`), so the deep copy refers to
/// `$PagedStateCopyWith` through the `mc_paging` barrel (T-0034-AC3).
@freezed
sealed class HolderState with _$HolderState {
  const factory HolderState.loading() = _Loading;

  const factory HolderState.success(PagedState<int> page) = _Success;
}

/// The same, as a plain class with the deep `copyWith`.
@freezed
abstract class HolderBox with _$HolderBox {
  const factory HolderBox({
    required PagedState<int> page,
    @Default('') String label,
  }) = _HolderBox;
}
