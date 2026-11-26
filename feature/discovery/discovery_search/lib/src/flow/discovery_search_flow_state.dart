import 'package:freezed_annotation/freezed_annotation.dart';

part 'discovery_search_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1). Pure Dart,
/// so the bloc that reads it stays Flutter-free (R15).
@freezed
abstract class DiscoverySearchFlowState with _$DiscoverySearchFlowState {
  const factory DiscoverySearchFlowState({
    /// The query the flow opened with (`/search?q=spi`): the field starts
    /// with it and it is searched once typing would have paused. Null opens
    /// on the recent searches.
    String? initialQuery,
  }) = _DiscoverySearchFlowState;
}
