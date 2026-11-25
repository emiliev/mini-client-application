import 'package:characters_list/src/domain/model/character_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'characters_list_flow_state.freezed.dart';

/// What the flow has selected, not which page shows (plan 01 §4.1): a
/// [previewId] puts the preview page on top of the list. Pure Dart, so the
/// blocs that update it stay Flutter-free (R15).
@freezed
abstract class CharactersListFlowState with _$CharactersListFlowState {
  const factory CharactersListFlowState({
    /// The team the list is filtered to; null for every team.
    String? teamId,

    /// The character whose preview is open.
    CharacterId? previewId,
  }) = _CharactersListFlowState;
}
