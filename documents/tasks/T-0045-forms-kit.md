# T-0045: `mc_forms` and `mc_ds_forms`: form state, validators, wizard steps (U20, U35, P1-14 AC4)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (kits; ADR-0011) |
| Branch | `fleet/T-0045-forms-kit` |
| Created | 2026-11-26 |
| Depends on | T-0022 (`mc_bloc_kit`), T-0030 (pure-kit conventions), T-0044 (`mc_ds_inputs`, for `mc_ds_forms`; build on its branch head or merge after it lands) |
| Related | plan 01 U20, U35, R6/C7 (validators live in `mc_forms` with solitary tests), P1-14 AC4 |

## Goal
The form and wizard kit for the FW exemplar (P1-20, `library_reading_list_editor`). Validation logic lives here, solitary-tested (R6), so FW features stay sociable-only.

## Scope
- **In:**
  - `utility/mc_forms` (pure Dart, no mixins, like `mc_paging`):
    - `FieldState<T>`: value, dirty, touched, error.
    - `FormState`: a map of fields, `isValid`, a submit status.
    - A `Validators` library: required, minLength, maxLength, pattern, range, plus `compose` and cross-field validators. Error codes are typed enums, not strings; features map codes to l10n.
    - `WizardController`: steps with per-step validation, `next` blocked when the step is invalid, `back`, a result on completion, and restored step state when going back.
    - A `FormController` that an `McBloc` uses (an `onState` callback, as `PagingController` does).
  - `utility/mc_ds_forms`:
    - `McFormScaffold` (a scrollable body and a sticky submit bar showing busy, disabled and error states);
    - `McWizardStepper` (a step indicator, Back/Next, with Next disabled when the step is invalid);
    - `McFieldGroup`, bound to `mc_forms` state and using `mc_ds_inputs`.
    - Goldens.
- **Out:** async validators that hit the backend (later), and date fields.

## Acceptance criteria
- **T-0045-AC1:** Validators are solitary-tested per rule and per composition. Cross-field validation works (confirm equals). Error codes are typed. Mutating any rule turns a test red.
- **T-0045-AC2:** P1-14 AC4: given wizard validators, errors are reported per step. Given an invalid step, `next` doesn't advance and the step's errors become visible (touched). `back` restores the previous step's values. Completing returns the result once. Double submit runs one completion.
- **T-0045-AC3:** `mc_ds_forms`:
  - Next is disabled with an invalid step, and the error text shows under the field.
  - The submit bar shows busy and blocks taps while submitting.
  - Goldens: 4 themes × 2 scales.
  - Semantics: the step indicator announces "Step n of m", and errors are announced.
- **T-0045-AC4:**
  - `mc_forms` is pure Dart (closure check with a negative control).
  - Layering: `mc_ds_forms` has no `mc_feature_flow` dependency (layering script).
  - Both are registered, coverage is ≥ 90 % each, and the fixtures check passes.
  - Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format.
  - Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-26: Created and dispatched (TL).
- 2026-11-26: Engineer: `mc_forms` first (pure Dart, no mixins; validators, `FieldState`, `McFormState`, `FormController`, `WizardController`), then `mc_ds_forms` on a merge of the T-0044 WIP branch (`McTextField` from `mc_ds_inputs`). One real survivor round per package (equivalent mutants removed, five tests added, one dead guard deleted). Handoff.

## Outcome
**Handed off** for verification on `fleet/T-0045-forms-kit`. Evidence: `documents/evidence/T-0045/engineer/` (gates, closure and layering report, full mutation run, mutation scripts). Design record and gotchas: [F-0045](../findings/F-0045-forms-kit-design.md).

### AC to test map
| AC | Tests (names contain the ID) |
|---|---|
| AC1 | `//utility/mc_forms:validators_test` (every rule at its boundary, empty and null, each composition, `matches` and `requiredWhen`, typed codes, `FieldDef` order); `form_controller_test` (cross-field error follows the other field) |
| AC2 | `//utility/mc_forms:wizard_controller_test` (errors per step, invalid step blocks `next` and touches only its fields, `back` restores values and touched, complete once, double complete one run, jump to first invalid step, failure and retry, dispose); `form_controller_test` (submit once, double submit, failure, `Error` propagates) |
| AC3 | `//utility/mc_ds_forms:forms_test` (Next disabled on an invalid step and the error under the field after blur, busy blocks taps, "Step n of m" announced as a live region, errors announced, 44 pt targets and the three `meetsGuideline` checks, no overflow at 1x, 2x, 3x with long German labels); `//utility/mc_ds_forms:golden_test` (7 components x 4 themes x 2 scales = 56 goldens) |
| AC4 | `//utility/mc_forms:purity_test`; `tool/checks/T-0045-AC4_closure_layering.sh` ([report](../evidence/T-0045/engineer/AC4_closure_layering.md), with positive and negative controls); `tool/checks/T-0045-AC4_gates.sh` ([report](../evidence/T-0045/engineer/gates.md)) |

### Gates
`test //...` 123/123; `build --config=lint //...`; `mc_arch_check`; `rules_fork.sh check`; `dart format`; `l10n_check`; fixtures closure (T-0031-AC6); closure and layering (T-0045-AC4): all PASS. Coverage (union of per-target LCOV): `mc_forms` 246/246 = 100 %, `mc_ds_forms` 143/143 = 100 %. Mutations: 96 (63 + 6 for `mc_forms`, 27 for `mc_ds_forms`), all killed; `documents/evidence/T-0045/engineer/mutations.sh` (with `mutations_ds.sh`) refuses a dirty tree. Locks are unchanged: first-party packages are not in `pubspec.lock`, and `MODULE.bazel.lock` did not change.

### Public API
**`package:mc_forms/mc_forms.dart`** (pure Dart, no mixins; depends on `mc_api_errors` and `mc_prelude`)
- `ValidationCode` (enum: `required`, `tooShort`, `tooLong`, `patternMismatch`, `belowMin`, `aboveMax`, `mismatch`, `invalid`) and `FieldError(code, {min, max})`.
- `Validator<T>`, `CrossValidator<T>`, `FieldSpec`, `FieldDef<T>(name, {initial, validators, crossValidators})`.
- `Validators`: `required`, `minLength`, `maxLength`, `pattern`, `range`, `compose`, and the cross-field `matches(otherField)`, `requiredWhen(condition)`.
- `FieldState<T>` (`value`, `initial`, `error`, `touched`, `dirty`, `visibleError`), `McFormState` (`fields`, `isValid`, `errors`, `visibleErrors`, `values`, `submitStatus`, `submitFailure`, `submitResult`), `SubmitStatus`, `FormValues` (`get<T>(name)`).
- `FormController({fields, onState})`: `setValue`, `touch`, `touchAll({names})`, `reset`, `submit<R>(action)` returning `Result<R, ApiFailure>?` (null when invalid, already submitting or disposed), `dispose`. `SubmitAction<R>`.
- `WizardStep(id, {fields})`, `WizardController<R>({steps, onState, onComplete})`: `setValue`, `touch`, `next()`, `back()`, `complete()`, `dispose`; `WizardState<R>`: `stepIndex`, `stepCount`, `stepId`, `isFirst`, `isLast`, `stepErrors(i)`, `isStepValid(i)`, `isCurrentStepValid`, `canGoNext`, `canGoBack`, `canComplete`, `isCompleting`, `isCompleted`, `result`, `failure`, `form`.

**`package:mc_ds_forms/mc_ds_forms.dart`** (Flutter; no `mc_feature_flow`)
- `McFormScaffold({body, submitLabel, busyLabel, onSubmit, isSubmitting, errorText, appBar})`: scrolling body, sticky bar (enabled, disabled, busy, error).
- `McWizardStepper({currentStep, stepCount, stepLabel, backLabel, nextLabel, onBack, onNext})` and `McWizardStepper.fromState(WizardState, {stepLabel, backLabel, nextLabel, finishLabel, onBack, onNext})`.
- `McFieldGroup({title, description, children})`, `McFormTextField({field, label, onChanged, onTouched, errorMessage, ...})` over `McTextField`; `McErrorMessage`, `McStepLabel` typedefs.

### Deviations and decisions for the TL
1. **`McFormState`, not `FormState`** (name clash with Flutter's; F-0045 item 1).
2. **`mc_forms` depends on `mc_api_errors` and `mc_prelude`, not `mc_bloc_kit`** (as `mc_paging`): the controllers take an `onState` callback, and `submit` / `complete` use `Result<R, ApiFailure>` like `PageFetcher`.
3. **Wizard Next is disabled when invalid** (AC3), so the "next doesn't advance and the errors become visible" path (AC2) is reached through the controller (`next()`), and through blur and `complete()` in the UI. A feature that wants the tap to reveal errors can pass an `onNext` that calls `next()` and stay enabled; the stepper does not forbid it.
4. **`mc_ds_forms` is built on `mc_ds_inputs` from `main` (T-0044 merged; the WIP merge was reconciled cleanly).** T-0044 was not on `main`. Once it merges, `git merge origin/main` removes the difference; only `McTextField` is used. The workspace `pubspec.yaml` conflict (adjacent lines) was resolved by keeping both entries.
5. **Own layering and closure script** (`tool/checks/T-0045-AC4_closure_layering.sh`) rather than editing `T-0040-AC3_layering.sh`: T-0044 also extends that one, and two edits would conflict. It scans the same things for `mc_ds_forms` and adds the `mc_forms` purity closure with negative controls.
6. No tests deleted, skipped or weakened; no `// ignore:`; no golden updated from an earlier state (all 56 are new). The findings index (`findings/README.md`) is not updated (TL-owned); F-0045 is new.

### Follow-ups
- `mc_ds_forms` has one bound widget (`McFormTextField`); bound switches, chips and steppers (over `mc_ds_inputs`) come when the FW exemplar needs them.
- Async validators and date fields are out of scope, as written.


## Review round (code review, ADR-0011)
All items fixed in one round, each with a `T-0045-AC1/2/3` test shown to fail without the fix (mutations `R-*` in `documents/evidence/T-0045/engineer/mutations_review.sh`).
1. **Typed binding:** `McFormState.fieldOf<T>(name)`. `McFormTextField` is bound to a live `FormController` (typing updates it, `reset` and `setValue` update the text) and to a `WizardController` in tests.
2. **`Validators.pattern`:** anchored with look-arounds (`(?<![\s\S])(?:pattern)(?![\s\S])`) and the flags copied. Used instead of `^(?:...)$` because a `multiLine` pattern would turn `^` and `$` into line anchors. Tests: `a|ab` on "ab", `\d+?` on "123", flags, multiLine.
3. **Blocked Next and submit:** the button stays disabled (semantics disabled, with a hint), and a tap calls `onBlockedNext` / `onBlockedSubmit`. `WizardController.touchCurrentStep()` is the new hook for the stepper (`fromState` now requires `onBlockedNext` and `blockedHint`). Not called while completing, completed or busy.
4. **Edits during submit:** `setValue` is ignored while submitting (`touch` cannot change anything then, as submit has touched every field, so it has no guard). `McFieldGroup(enabled:)` and a busy `McFormScaffold` disable bound fields through an internal `McFormScope` (a nested scope can only narrow).
5. **Lengths:** `package:characters` (a direct dependency of `mc_forms`; the lock is unchanged). 10 emoji pass `maxLength(10)`.
6. **Stale value:** the text syncs only when the field's value changed, with the selection clamped and composing kept.
7. **`complete()`** touches only the first invalid step's fields; `next()` and `canGoNext` are off once completed.
8. **`onTouched`** fires once; a reset (touched back to false) re-arms it.
9. Gates script header names the packages.

Golden changes: the 8 `form_scaffold_busy.*` goldens (4 themes x 2 scales), because bound fields are now disabled while busy (the fields show the disabled fill). I looked at light x1 and highContrastDark x2: fields greyed, spinner and "Saving" unchanged. No other golden changed. Evidence re-run on the merge of `origin/main`: gates PASS, coverage 266/266 and 195/195, 124/124 mutations killed.
