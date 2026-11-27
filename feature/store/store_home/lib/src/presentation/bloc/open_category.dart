import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:store_home/src/flow/store_home_flow_state.dart';

/// A category opens as a page of this flow, not a route (plan 01 §4.1): the
/// categories grid and a category banner both open it here.
extension OpenCategoryInFlow on FeatureFlowController<StoreHomeFlowState> {
  /// Opens [category]'s page above the store home. One at a time: a second
  /// tap while the page slides in keeps the first (F-0031 fact 9).
  void openCategory(OpenCategory category) {
    if (state.category == null) {
      update((s) => s.copyWith(category: category));
    }
  }
}
