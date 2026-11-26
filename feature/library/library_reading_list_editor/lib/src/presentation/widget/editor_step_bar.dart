import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/presentation/bloc/reading_list_editor_bloc.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_forms/mc_forms.dart';

/// The step bar at the foot of each step page: "Step n of 3", Back, and
/// Next (Create list / Save changes on the last step).
///
/// Bound to the wizard ([McWizardStepper.fromState]) only on the page of the
/// wizard's current step. A page below it (still mounted, and visible during
/// a back swipe) shows its own step with both buttons off, so it never reads
/// "Step 2 of 3" on step 1's page.
class EditorStepBar extends StatelessWidget {
  const EditorStepBar({
    required this.step,
    required this.wizard,
    required this.existing,
    super.key,
  });

  /// The step this page shows, 0-based.
  final int step;
  final WizardState<ReadingListId> wizard;

  /// Edit mode: the last step saves changes instead of creating a list.
  final bool existing;

  @override
  Widget build(BuildContext context) {
    final l10n = ReadingListEditorL10n.of(context);
    String stepLabel(int step, int total) =>
        l10n.readingListEditorStep(step, total);
    final next = wizard.isLast
        ? (existing ? l10n.readingListEditorSave : l10n.readingListEditorCreate)
        : l10n.readingListEditorNext;
    if (wizard.stepIndex != step) {
      return McWizardStepper(
        currentStep: step,
        stepCount: wizard.stepCount,
        stepLabel: stepLabel,
        backLabel: l10n.readingListEditorBack,
        nextLabel: l10n.readingListEditorNext,
        onBack: null,
        onNext: null,
      );
    }
    final bloc = context.read<ReadingListEditorBloc>();
    return McWizardStepper.fromState(
      wizard,
      stepLabel: stepLabel,
      backLabel: l10n.readingListEditorBack,
      nextLabel: next,
      finishLabel: next,
      onBack: () => bloc.add(const ReadingListEditorEvent.back()),
      onNext: () => bloc.add(
        wizard.isLast
            ? const ReadingListEditorEvent.submit()
            : const ReadingListEditorEvent.next(),
      ),
      onBlockedNext: () =>
          bloc.add(const ReadingListEditorEvent.blockedNext()),
      blockedHint: l10n.readingListEditorBlockedHint,
    );
  }
}
