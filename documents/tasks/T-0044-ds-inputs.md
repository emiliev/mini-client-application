# T-0044: `mc_ds_inputs`: text and search fields, chips, segmented control, stepper (U28 subset)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (DS widgets; ADR-0011) |
| Branch | `fleet/T-0044-ds-inputs` |
| Created | 2026-11-26 |
| Depends on | T-0019 (DS foundation), T-0040 (`mc_ds_navigation`, layering script) |
| Related | plan 01 U28; F-0014, F-0030, F-0039 |

## Goal
The DS input widgets the SR exemplar (search) and FW exemplar (forms and wizard) need, so features never hand-roll inputs.

## Scope
- **In:** `utility/mc_ds_inputs`:
  - `McTextField`: label, hint, helper/error text, prefix and suffix, obscure, `maxLength` counter, `TextInputAction`. It is controlled: it takes a controller and `onChanged`.
  - `McSearchField`: a search icon; a clear button only when there is text; submit; autofocus option. Debounce is not the widget's job; `mc_paging`'s `DebouncedQuery` does that.
  - `McChip` (filter/choice, selected state) and `McChipGroup` (wraps, single or multi select).
  - `McSegmented` (2–5 segments).
  - `McStepper` (an integer with min, max and step).
  - Goldens for 4 themes × 2 text scales, through `mc_test_utils`.
- **Out:** sliders, date/time pickers, dropdowns (later).

## Acceptance criteria
- **T-0044-AC1:** Goldens exist for every widget and state (empty, filled, focused, error, disabled, selected) in 4 themes × 2 scales. No overflow at 2× (and at a 3× probe in a test), including long German labels.
- **T-0044-AC2:** Behaviour:
  - `McSearchField`'s clear button appears only with text; clearing empties the field and calls `onChanged('')`.
  - `McChipGroup` single-select deselects the previous chip; multi-select toggles.
  - `McStepper` clamps at min and max, and those buttons are disabled.
  - `McSegmented` reports the tapped index.
  - Every widget is controlled: an external value change updates the UI without feedback loops.
- **T-0044-AC3:** Semantics:
  - text fields have labels and error announcements;
  - chips are toggles with selected state;
  - segments are tabs or toggles with selected state;
  - stepper buttons are labelled increase and decrease, with the value;
  - every tap target is ≥ 44 pt;
  - `meetsGuideline` passes (tap target, labeled tap target, text contrast) in all themes.
- **T-0044-AC4:** Layering: no dependency on `mc_feature_flow` or `mc_paging`. Extend `tool/checks/T-0040-AC3_layering.sh`, or its successor, to cover this package. Registered; coverage ≥ 90 %; fixtures check passes; gates pass (`test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format). Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-26: Created and dispatched (TL).
