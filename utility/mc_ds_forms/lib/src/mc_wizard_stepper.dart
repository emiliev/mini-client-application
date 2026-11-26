import 'package:flutter/material.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_forms/mc_forms.dart';

/// Builds "Step 2 of 3" in the user's language. [step] is 1-based.
typedef McStepLabel = String Function(int step, int total);

/// A wizard's sticky bar: a step indicator and Back / Next buttons.
///
/// Next is disabled ([onNext] null) while the step is invalid. The indicator
/// is one semantics node that reads the [stepLabel] text ("Step n of m") and
/// is a live region, so a screen reader announces each step change. Use
/// [McWizardStepper.fromState] to bind it to a `WizardController`'s state.
class McWizardStepper extends StatelessWidget {
  const McWizardStepper({
    required this.currentStep,
    required this.stepCount,
    required this.stepLabel,
    required this.backLabel,
    required this.nextLabel,
    required this.onBack,
    required this.onNext,
    super.key,
  }) : assert(stepCount > 0, 'a wizard has at least one step'),
       assert(
         currentStep >= 0 && currentStep < stepCount,
         'currentStep is out of range',
       );

  /// Binds the stepper to [state]: Back is enabled when the wizard can go
  /// back; the last step shows [finishLabel] and is enabled when the wizard
  /// can complete; every other step shows [nextLabel] and is enabled when
  /// its step is valid. While the wizard completes, both buttons are
  /// disabled. [onNext] runs for "Next" and for "Finish".
  factory McWizardStepper.fromState(
    WizardState<Object?> state, {
    required McStepLabel stepLabel,
    required String backLabel,
    required String nextLabel,
    required String finishLabel,
    required VoidCallback onBack,
    required VoidCallback onNext,
    Key? key,
  }) => McWizardStepper(
    key: key,
    currentStep: state.stepIndex,
    stepCount: state.stepCount,
    stepLabel: stepLabel,
    backLabel: backLabel,
    nextLabel: state.isLast ? finishLabel : nextLabel,
    onBack: state.canGoBack ? onBack : null,
    onNext: (state.isLast ? state.canComplete : state.canGoNext)
        ? onNext
        : null,
  );

  /// The current step, 0-based.
  final int currentStep;
  final int stepCount;
  final McStepLabel stepLabel;
  final String backLabel;
  final String nextLabel;

  /// Null disables Back.
  final VoidCallback? onBack;

  /// Null disables Next.
  final VoidCallback? onNext;

  static const backKey = Key('mc_wizard_stepper_back');
  static const nextKey = Key('mc_wizard_stepper_next');

  @override
  Widget build(BuildContext context) {
    final p = context.mcPalette;
    final label = stepLabel(currentStep + 1, stepCount);
    return Material(
      color: p.surface,
      shape: Border(top: BorderSide(color: p.outline)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: McInsets.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                liveRegion: true,
                label: label,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < stepCount; i++) ...[
                          if (i > 0) const McGap.xs(),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i <= currentStep
                                    ? p.primary
                                    : p.surfaceVariant,
                                borderRadius: McRadius.smAll,
                              ),
                              child: const SizedBox(height: 4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const McGap.sm(),
                    Text(
                      label,
                      style: McTypeScale.caption.copyWith(
                        color: p.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const McGap.md(),
              Row(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: backKey,
                      child: McButton(
                        label: backLabel,
                        variant: McButtonVariant.secondary,
                        onPressed: onBack,
                        expand: true,
                      ),
                    ),
                  ),
                  const McGap.md(),
                  Expanded(
                    child: KeyedSubtree(
                      key: nextKey,
                      child: McButton(
                        label: nextLabel,
                        onPressed: onNext,
                        expand: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
