# T-0044: `mc_ds_inputs`: text and search fields, chips, segmented control, stepper (U28 subset)

| Field | Value |
|---|---|
| Status | In Verification |
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
- 2026-11-26: Engineer (Sonnet) built `mc_ds_inputs`, 33+ behaviour and semantics tests, 160 goldens, the layering and gates checks and a 60-mutation script. Merged `origin/main` (T-0043, no conflicts, no lock change). Handed off.

## Outcome
**Status:** Done, ready for verification. Branch `fleet/T-0044-ds-inputs`.

### Public API (stable: T-0045 builds `mc_ds_forms` on it)
Barrel `package:mc_ds_inputs/mc_ds_inputs.dart`. Every widget is controlled, needs no `Scaffold` (it brings its own transparent `Material`), and takes accessible names as parameters (the DS has no l10n, so the feature passes localised strings).
- `McTextField({required controller, required label, onChanged, onSubmitted, hint, helperText, errorText, prefix, suffix, obscureText = false, maxLength, maxLines = 1, textInputAction, keyboardType, inputFormatters, enabled = true, autofocus = false, focusNode})`. The label is the placeholder and then floats. `errorText` replaces the helper text, is drawn in the error colour and is a live region. `onChanged` fires for user edits only. Needs a bounded width (280 pt when unbounded, `mcFieldUnboundedWidth`).
- `McSearchField({required controller, required label, required clearLabel, onChanged, onSubmitted, autofocus = false, enabled = true, focusNode})`: pill, search icon, clear button only with text (clears, calls `onChanged('')`, takes the focus back), `TextInputAction.search`. No debounce.
- `McChip({required label, required selected, required onSelected (ValueChanged<bool>?, null disables), icon, exclusive = false})`.
- `McChipOption<T>({required value, required label, icon})`; `McChipGroup<T>.single({required options, required selected (T?), required onChanged (ValueChanged<T?>?), allowDeselect = false})`; `McChipGroup<T>.multi({required options, required selected (Set<T>), required onChanged (ValueChanged<Set<T>>?)})`. A `Wrap`; a null `onChanged` disables all; `multi` passes a new set and never mutates the old one.
- `McSegment({required label, icon, key})`; `McSegmented({required segments (2 to 5), required selectedIndex, required onChanged (ValueChanged<int>?)})`. Label scale capped at `McSegmented.labelMaxScale` (1.5).
- `McStepper({required value, required onChanged (ValueChanged<int>?), required label, required decreaseLabel, required increaseLabel, min = 0, max = 99, step = 1, valueText})`: new values are clamped to `[min, max]`; the buttons disable at the bounds; the group carries `label` and the value.
- `mcFieldUnboundedWidth`.
Layering: depends on `mc_ds_buttons` (`McIconButton` for the clear button and the stepper), `mc_ds_layout`, `mc_ds_theme`, `mc_ds_tokens`; never `mc_feature_flow` or `mc_paging`.

### Interpretation choices
- "Chips are toggles with selected state": a chip is a **button with the `selected` flag** (as Material's `FilterChip`), plus `inMutuallyExclusiveGroup` in a single-select group. The `toggled` flag was not used: VoiceOver reads it as a switch, which is wrong for a filter chip.
- Segments: buttons with `selected` in an exclusive group (not `tab` roles: a segmented control does not own a panel).
- Stepper: one group (`label`, `value`) containing two buttons named by `decreaseLabel` and `increaseLabel`; the drawn number is excluded so the value is read once.
- The golden "focused" state exists for the text and search fields only: a chip, segment or stepper has no persistent focus look on iOS touch.

### AC to evidence
| AC | Evidence |
|---|---|
| AC1 | `utility/mc_ds_inputs/test/golden_test.dart`: 20 components x 4 themes x 2 scales = 160 goldens (text field: empty, filled, focused, error, disabled, affixes with counter and obscure, long German; search: empty, filled, focused, disabled; chip states (unselected, selected, icon, disabled, disabled selected, long); chip group single, multi, disabled; segmented 2, 5, German, disabled; stepper mid, min, max, disabled). All looked at; samples in `documents/evidence/T-0044/engineer/goldens/`. No-overflow tests in `inputs_test.dart`: "T-0044-AC1 every widget with long German labels at 1.0x / 2.0x / 3.0x", a 280 pt column, unbounded width, loose Scaffold body (no stretching), no ancestor scroll, segment label cap, stepper number scales down |
| AC2 | `inputs_test.dart` "T-0044-AC2 ...": search clear (appears only with text, empties, calls `onChanged('')`, refocuses), submit, autofocus, action; text field controlled / helper / error / counter / obscure / action / prefix and suffix / disabled; single chip group (deselects previous, no deselect by default, `allowDeselect`), multi (toggle, new set), disabled groups, lone chip; stepper clamp and disabled buttons, step, out-of-range value, `valueText`; segmented reports the tapped index (also the selected one) and is inert when disabled; one test changes every value from outside and asserts no callback fired |
| AC3 | `inputs_test.dart` "T-0044-AC3 ...": text field label and live-region error; search field label and clear button; chips (button, `selected`, group flag, disabled has no tap); segments; stepper group and button names; every target at least 44 pt (also at 0.5x text); `meetsGuideline` tap target, labelled target and text contrast for every widget in all 4 themes; text-field colours reach 4.5:1 against their fill in all 4 themes (the platform guideline skips text fields, F-0043 fact 3); disabled outlines are not dimmed in high contrast |
| AC4 | `tool/checks/T-0044-AC4_layering.sh` ([report](../evidence/T-0044/engineer/ac4-layering.md)): re-runs T-0040-AC3; neither `mc_feature_flow` nor `mc_paging` in the closure of the library or either test target; sources clean; positive control (characters_list sees both); 10 negative controls (BUILD dep, pubspec, lib import, import with trailing `///`, test import, each for both packages). `tool/checks/T-0044-AC4_gates.sh` ([report](../evidence/T-0044/engineer/ac4-gates.md)): `test //...` (touched packages uncached), lint, `mc_arch_check`, `rules_fork.sh check`, format, l10n_check, provenance, fixtures closure (covers the new package), layering; **coverage `mc_ds_inputs` 99.2 % (258/260)**, `mc_ds_navigation` 93.0 % |

Mutations ([script](../evidence/T-0044/engineer/mutations.sh), [log](../evidence/T-0044/engineer/mutations.log)): 60 of 60 killed (behaviour, semantics, contrast and golden mutations). The first run found five weak spots, all fixed with tests: the clear button's refocus was not asserted (focus never left the field), the stepper's number was not asserted to scale down, the text-field colours were not checked (the platform guideline skips them), the chip's 44 pt minimum held by accident at 1x, and the error text was not asserted to be rendered. One equivalent mutant was dropped (a segment `InkWell` with `onTap` set while disabled behaves like null).

### Test integrity
New package; nothing deleted, skipped or weakened; no `// ignore:`; no existing golden changed. One edit outside the package: the root `pubspec.yaml` workspace list, and the layering check (new `T-0044-AC4_layering.sh`, which re-runs `T-0040-AC3_layering.sh` unchanged).

### Notes
- Finding [F-0043](../findings/F-0043-ds-inputs-gotchas.md). Decisions: none needing an ADR. `pubspec.lock` and `MODULE.bazel.lock` did not change. `origin/main` (T-0043) merged cleanly.
- The text field's hint shows only while the field is focused and empty, as Flutter draws it; the empty golden shows the label as the placeholder.
- Follow-ups: five segments at 2x and 3x break words in narrow cells ("Hel / den"), which is legal but plain; a feature with long labels should use fewer segments or a chip group. A "show password" suffix and a date field are for `mc_ds_forms` (T-0045). Android tap targets (48 dp) are not checked (iOS first).

## Review round (after `/code-review`)
No signature changed.
1. **Intrinsic sizing (important).** `boundedFieldWidth` is now a small render object (`RenderProxyBox`, 280 pt fallback, intrinsic width 280) and `McSegmented` uses its own row render object (equal cells when bounded, natural widths when not, intrinsic width = widest cell x count, height from intrinsics). No `LayoutBuilder` is left. Tests "T-0044-AC1 every input lays out under IntrinsicWidth / IntrinsicHeight / AlertDialog" cover all five widgets, plus equal cells under `IntrinsicWidth` and a 280 pt field. The unbounded-width tests stay green. A first version stretched the segmented control in a loose body (its height came from a layout under a loose height); the existing "does not stretch" test caught it, and the height now comes from intrinsics.
2. `BUILD.bazel`: the library glob excludes `MC_GENERATED_DART`.
3. `McSearchField` disabled fill is `background` (flat), not `surface` (raised).
4. Chip: a `GestureDetector` takes the tap on the whole 44 pt box; the `InkWell` is inside the drawn pill (`Ink`), so only the pill ripples. Test: the `InkWell` is under 44 pt, the box is 44 pt, and a tap in the strip above the pill selects.
5. Gates script header names the utility packages.
6. Layering script checks the restore with `cmp` against snapshots taken before the controls.

**Goldens changed (4 of 160, all looked at):** `search_field_disabled.{light,dark}.{x1,x2}`: the field now has the page's flat background with the lighter outline and muted text, so it reads as disabled; high-contrast variants are unchanged (surface equals background there). Chip goldens are unchanged (the ripple is not in them).
Mutations: 65 of 65 killed (6 added or replaced for this round, [log](../evidence/T-0044/engineer/mutations.log)). Gates and layering PASS; coverage `mc_ds_inputs` 95.6 % (325/340), `mc_ds_navigation` 93.0 %. `origin/main` had nothing new.
