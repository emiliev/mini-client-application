import 'package:flutter/material.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';
import 'package:mc_forms/mc_forms.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

String _stepLabel(int step, int total) => 'Step $step of $total';

String _message(FieldError e) => switch (e.code) {
  ValidationCode.required => 'Required',
  ValidationCode.tooShort => 'At least ${e.min} characters',
  _ => 'Invalid',
};

const _longDe =
    'Bitte geben Sie hier den vollstaendigen Namen der Leseliste ein';

Widget _fields({bool errors = false}) => McFieldGroup(
  title: 'Reading list',
  description: 'Name your list and say what it is for',
  children: [
    McFormTextField(
      field: FieldState<String>(
        value: errors ? 'ab' : 'Weekend reads',
        initial: '',
        error: errors
            ? const FieldError(ValidationCode.tooShort, min: 3)
            : null,
        touched: true,
      ),
      label: 'Name',
      onChanged: (_) {},
      onTouched: () {},
      errorMessage: _message,
    ),
    McFormTextField(
      field: FieldState<String>(
        value: errors ? '' : _longDe,
        initial: '',
        error: errors ? const FieldError(ValidationCode.required) : null,
        touched: true,
      ),
      label: 'Beschreibung',
      onChanged: (_) {},
      onTouched: () {},
      errorMessage: _message,
    ),
  ],
);

Widget _page(BuildContext context, McFormScaffold Function() build) =>
    SizedBox(height: MediaQuery.sizeOf(context).height, child: build());

McWizardStepper _stepper({
  required int current,
  VoidCallback? onBack,
  VoidCallback? onNext,
  String next = 'Next',
}) => McWizardStepper(
  currentStep: current,
  stepCount: 4,
  stepLabel: _stepLabel,
  backLabel: 'Back',
  nextLabel: next,
  onBack: onBack,
  onNext: onNext,
);

void main() {
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'form_scaffold_enabled',
    builder: (c) => _page(
      c,
      () => McFormScaffold(
        body: _fields(),
        submitLabel: 'Save list',
        busyLabel: 'Saving',
        onSubmit: () {},
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'form_scaffold_disabled_errors',
    builder: (c) => _page(
      c,
      () => McFormScaffold(
        body: _fields(errors: true),
        submitLabel: 'Save list',
        busyLabel: 'Saving',
        onSubmit: null,
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'form_scaffold_busy',
    settle: const Duration(milliseconds: 400),
    builder: (c) => _page(
      c,
      () => McFormScaffold(
        body: _fields(),
        submitLabel: 'Save list',
        busyLabel: 'Saving',
        onSubmit: () {},
        isSubmitting: true,
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'form_scaffold_failed',
    builder: (c) => _page(
      c,
      () => McFormScaffold(
        body: _fields(),
        submitLabel: 'Save list',
        busyLabel: 'Saving',
        onSubmit: () {},
        errorText: 'You are offline. Check your connection and try again.',
      ),
    ),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'wizard_stepper_invalid',
    height: 160,
    heightAtScale2: 260,
    builder: (_) => _stepper(current: 0, onNext: null),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'wizard_stepper_middle',
    height: 160,
    heightAtScale2: 260,
    builder: (_) => _stepper(current: 2, onBack: () {}, onNext: () {}),
  );
  mcGoldenMatrix(
    acId: 'T-0045-AC3',
    component: 'wizard_stepper_last_long_labels',
    height: 160,
    heightAtScale2: 320,
    builder: (_) => _stepper(
      current: 3,
      onBack: () {},
      onNext: () {},
      next: 'Leseliste speichern',
    ),
  );
}
