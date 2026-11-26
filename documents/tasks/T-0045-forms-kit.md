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
