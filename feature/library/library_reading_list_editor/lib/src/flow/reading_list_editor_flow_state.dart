import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';

part 'reading_list_editor_flow_state.freezed.dart';

/// The step pages that are open: step 0 (details) is the flow's root, step 1
/// (comics) and step 2 (order and review) are pushed on it, so a back
/// gesture on a later step returns to the step before it inside the flow.
/// Pure Dart, so the blocs that update it stay Flutter-free (R15).
///
/// The wizard's values are not here: they live in the editor bloc's
/// `WizardController`, which outlives the step pages. A pop restores the
/// flow state the lower page had (`FeatureFlow`), which would drop what was
/// entered on the popped step; the wizard keeps it (T-0048-AC6).
@freezed
abstract class ReadingListEditorFlowState with _$ReadingListEditorFlowState {
  const factory ReadingListEditorFlowState({
    /// The list being edited; null when a new list is created. The flow
    /// starts from the id alone (plan 01 §4.4).
    ReadingListId? editing,

    /// The deepest open step page (0 to 2). It mirrors the wizard's step:
    /// the bloc writes it after each step change, and a pop of a step page
    /// (back gesture, back button) is applied to the wizard.
    @Default(0) int step,
  }) = _ReadingListEditorFlowState;
}
