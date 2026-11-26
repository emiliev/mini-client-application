# F-0045: Forms kit design: what `mc_forms` and `mc_ds_forms` decide, and the gotchas met

- **Date:** 2026-11-26
- **Author:** crew: Engineer (T-0045)
- **Type:** Design record / Gotcha
- **Related:** T-0045, plan 01 U20, U35, R6/C7, P1-14 AC4, F-0029, F-0039

## Design decisions (for the FW exemplar)
1. **`McFormState`, not `FormState`.** The task text says `FormState`, but `mc_ds_forms` always imports Flutter, whose `FormState` would clash in every file that imports both. The prefix keeps the pure kit and the widgets importable together without `hide`.
2. **Errors are always computed; showing them is the UI's call.** `FieldState.error` is current for the value at all times, and `visibleError` is `error` only once the field is `touched`. A field becomes touched on blur (`McFormTextField.onTouched`), on a failed `next()` (the step's fields only), and on `submit` / `complete` (all fields). So "Next is disabled" and "the error shows under the field" are two separate facts and neither needs a timer.
3. **Every change re-checks every field.** A cross-field rule (`Validators.matches('password')`) therefore follows the other field without the form knowing who depends on whom. The cost is O(fields) per keystroke, which is trivial for forms.
4. **Typed codes plus limits, no text.** `FieldError(code, min:, max:)`; features map `ValidationCode` to l10n and quote `min`/`max`. There is no `custom(String)` escape hatch. A feature rule returns `FieldError(ValidationCode.invalid)`.
5. **Optional means "empty passes".** Every rule except `required` / `requiredWhen` passes null and `""`, so `compose([required(), minLength(3)])` is a required field and `minLength(3)` alone is an optional one.
6. **`pattern` needs a whole-text match.** `RegExp.hasMatch` finds a part; the rule uses `matchAsPrefix` and checks `end == length`, so `[a-z]+` rejects `abc1`.
7. **One form over all wizard steps.** `WizardController` builds one `FormController` from every step's fields. Back-and-forth keeps values and touched state for free, and a cross-field rule can read a field of another step. `complete()` touches everything, jumps to the first invalid step (and returns null) or runs `onComplete` once. A second call while it runs or after it succeeded returns null; the first call's future carries the result and `WizardState.result` keeps it.
8. **`next()` on the last step does nothing.** The UI calls `complete()` there. `McWizardStepper.fromState` shows the finish label on the last step and enables it from `canComplete`.
9. **A failed submit is not a dead end.** The status becomes `failed` with the `ApiFailure`, values stay, and editing any field moves it back to `idle`. An `Error` (a bug) propagates and leaves the status `idle`, as `PagingController` does.
10. **No disposed check in `WizardController._emit`.** Every public method is guarded and the inner `FormController` stops emitting on dispose, so the check was dead code that no test could reach (the mutation survived).

## Gotchas
- **`fvm flutter test` cannot run `mc_ds_forms` tests.** They import `mc_test_utils`, whose closure needs generated `*.g.dart`. Use `bazel test //utility/mc_ds_forms:forms_test`, or `tool/ide_sync` first.
- **A progress indicator is empty in a golden taken at frame 0.** The busy golden uses `settle: 400 ms` so the arc is drawn at a deterministic frame. Without it the spinner is a single dot and proves nothing.
- **Error text is found by `find.bySemanticsLabel`, not `find.text`.** `McTextField` puts the error in a live-region node of its own; `find.text` returns the `Text` node, whose merged semantic data may have an empty label. Pump about a second first, as the T-0044 test does.
- **A mutation `value is! Object` for the null case is equivalent** (`is! Object` is true only for null). Mutate with `false ||` instead.
- **A tall `Column` inside a `SingleChildScrollView` is not lazy,** so `find.text('row 29')` finds it before scrolling. Test position (`getTopLeft().dy`), not presence.
- **`mc_ds_forms` depends on `mc_ds_inputs` (T-0044).** While T-0044 is unmerged this branch carries a merge of `fleet/T-0044-ds-inputs`; once it lands on `main`, merging `origin/main` removes the difference.

Evidence: `documents/evidence/T-0045/engineer/`.
