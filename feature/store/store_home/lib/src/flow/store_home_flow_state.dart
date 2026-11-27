import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:store_home/src/domain/model/category_id.dart';

part 'store_home_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,
/// so the blocs that update it stay Flutter-free (R15).
@freezed
abstract class StoreHomeFlowState with _$StoreHomeFlowState {
  const factory StoreHomeFlowState({
    /// The flow opened at this category (`/store/categories/:id`): the
    /// category page is its only page, so Back leaves the flow (to the
    /// store route below it, T-0049's nested back stack).
    OpenCategory? rootCategory,

    /// The category whose page is open above the store home.
    OpenCategory? category,
  }) = _StoreHomeFlowState;
}

/// A category page to show: its id, and its name when the opener knew it
/// (the categories grid does; a banner and a deep link do not, so the page
/// looks it up).
@freezed
abstract class OpenCategory with _$OpenCategory {
  const factory OpenCategory({required CategoryId id, String? name}) =
      _OpenCategory;
}
