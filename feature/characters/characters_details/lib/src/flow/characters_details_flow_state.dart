import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'characters_details_flow_state.freezed.dart';

/// What the flow shows, not which page is on top (plan 01 §4.1): the
/// character it opened on. Pure Dart, so the blocs that read it stay
/// Flutter-free (R15).
@freezed
abstract class CharacterDetailsFlowState with _$CharacterDetailsFlowState {
  const factory CharacterDetailsFlowState({
    /// The character the flow opened on (`/characters/:id`); the flow starts
    /// from the id alone (plan 01 §4.4).
    required CharacterId characterId,
  }) = _CharacterDetailsFlowState;
}
