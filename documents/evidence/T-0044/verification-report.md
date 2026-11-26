# Verification report — T-0044: `mc_ds_inputs` (text and search fields, chips, segmented, stepper)

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0044-ds-inputs` @ `b0260ce`
- **Simulator:** none. No AC needs e2e (DS widgets; goldens and widget tests only).
- **Verdict:** PASS

## Gates re-run independently
Clean Bazel output base `/tmp/mc-ob-T-0044-verifier`, shut down at the end.

| Gate | Command | Result |
|---|---|---|
| Goldens regenerate | `run //utility/mc_ds_inputs:golden_test -- --update-goldens` (clean base) | 160 written, 160 passed, `git status` clean: **byte-identical** to the committed PNGs |
| All gates | `tool/checks/T-0044-AC4_gates.sh --role verifier` | PASS on all 10 rows: `test //...` (117 tests, touched packages uncached), `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, flow_builder provenance, fixtures closure, layering, coverage |
| Coverage (own parser) | union of `inputs_test` and `golden_test` `coverage.dat`, `package:mc_ds_inputs/src/*` `DA:` lines | **325/340 = 95.6 %** (matches the script; at least 90 %). Per file: `field_style` 39/45, `mc_chip` 40/41, `mc_chip_group` 26/26, `mc_search_field` 42/42, `mc_segmented` 110/118, `mc_stepper` 34/34, `mc_text_field` 34/34 |
| Layering negative control | `mc_paging: any` added to `utility/mc_ds_inputs/pubspec.yaml` only, then `T-0044-AC4_layering.sh` | **rc=1, FAIL**, names `pubspec.yaml:17`. Restored; the clean re-run is rc=0 |
| BUILD glob | read `utility/mc_ds_inputs/BUILD.bazel` | the library glob has `exclude = MC_GENERATED_DART`, loaded from `//tool/bazel:defs.bzl` |
| Formatting | in the gates script (`dart format --set-exit-if-changed` over app, feature, spike, utility and the tools) | PASS |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0044-AC1 | Goldens for all states, 4 themes × 2 scales; no overflow at 2× and 3×, with long German labels | `golden_test` (20 components × 4 × 2 = 160); `inputs_test` "T-0044-AC1 no overflow" (1×, 2×, 3× on `_everything()`, a 280 pt column, a stepper that scales down); "intrinsic sizing" group | **Yes.** The goldens are deterministic (my regeneration from a clean base is byte-identical to the committed set). I viewed 6 (below). Overflow tests assert `takeException() == null`. Mutations M3 and M5 to M6 turn goldens red | PASS |
| T-0044-AC2 | Search clear; chip single and multi; stepper clamp; segmented index; controlled | 16 "T-0044-AC2" tests, among them "search clear button appears only with text and clears", "single-select chip group deselects the previous chip", "multi-select ... toggles and copies the set", "stepper clamps at min and max and disables buttons", "segmented reports the tapped index", "an external value change updates every widget without ..." | **Yes.** They tap, then assert the callback values, and the clear test asserts `onChanged('')`. The controlled test asserts no callback fired. Mutations M4, M5, M6, M8 and M9 each fail them | PASS |
| T-0044-AC3 | Labels, live-region error, chip and segment selected state, stepper labels and value, tap targets ≥ 44 pt, `meetsGuideline` in all themes | "T-0044-AC3" group (label and live-region error, search label, chips as buttons with `selected`, segments in an exclusive group, scaled-down tap targets, "every tap target is at least 44 pt"); `meetsGuideline` ×4 themes (`iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, one widget per page); text-field contrast 4.5:1 ×4 themes | **Yes.** They read `SemanticsData` flags, and the contrast tests measure colours because the platform guideline skips text fields (F-0043 fact 3). Mutation M7 (`selected: false` on segments) fails | PASS |
| T-0044-AC4 | Layering, registered, coverage ≥ 90 %, gates, `MC_GENERATED_DART` glob | `T-0044-AC4_layering.sh`, `T-0044-AC4_gates.sh` | **Yes.** My own negative control (pubspec-only `mc_paging`) FAILs, the clean tree PASSes, coverage is 95.6 % by my parser, the gates are all PASS, the BUILD glob is correct. The package is in the root `pubspec.yaml` workspace | PASS |

### The review's important fix (intrinsics) and the chip tap strip
- **Intrinsics, positive.** `inputs_test` "every input lays out under IntrinsicWidth / IntrinsicHeight / AlertDialog without throwing" covers all 5 widgets and passes. **Negative:** M1 puts a `LayoutBuilder` back in `boundedFieldWidth` and the new `inputs_test` goes **red**. Restored.
- **My own probe** (a temporary test, deleted; it was not committed). `McTextField` (helper and error text) and `McSearchField`, each at 1×, 2× and 3×, no exception in any case:

  | Layout | Width of the field |
  |---|---|
  | `Row` + `Expanded` | fills the row (800) |
  | `Row` + `Flexible` | fills the row (800); `Flexible` is a loose fit, but a field takes the maximum, as `TextField` does |
  | `Row` between a `Text` and an `Icon` | the remaining width (760.75 at 1×) |
  | `IntrinsicHeight` over `Row`, with `Expanded` | fills the row |
  | `IntrinsicWidth` over a `Column` | 280 at 1×; 484 at 2× and 724 at 3×, because the longer sibling text drives it |
  | bare `Row` | 280 (`mcFieldUnboundedWidth`) |
  | horizontal scroll view | 280 |
- **Chip tap strip.** The box is 46 pt (372.8..427.3, 277..323) and the `InkWell` is 36 pt (373.8..426.3, 282..318), inset by 5 pt and 1 pt, so it sits inside the pill. A tap 1 pt below the top edge and 1 pt above the bottom edge of the box selects; a tap 3 pt outside the box does not. The ripple lives in the `Ink` pill (the `InkWell` rect), not the 44 pt box.
- The shipped test "the drawn chip pill, not the 44 pt box, takes the ripple" asserts the box ≥ 44 pt, the ink < 44 pt, and the strip tap. M2 (the `GestureDetector.onTap` removed) turns it red.

### Goldens viewed (full-size PNGs are 750 px wide)
| Golden | What is visible |
|---|---|
| `search_field_disabled.light.x2.png` | A pill with the flat page background and a lighter outline. The icon and the "Search characters" text are muted, so it reads as disabled. This is one of the 4 goldens changed in the review round; no clear button |
| `search_field_disabled.dark.x1.png` | The same in dark: a flat near-black fill with a faint outline and muted text. A second changed golden |
| `chip_group_single.dark.x2.png` | Four chips wrapped. "Bösewichte" is selected: a filled coral pill, a check icon and dark text. The unselected chips have an outline. "Donaudampfschifffa…" is ellipsised inside the pill, with no overflow |
| `segmented_german.light.x2.png` | Three equal cells, the selected one in solid red with white text. Long words break and ellipsise ("Zuletzt hinzug…"); no overflow stripes; text legible |
| `stepper_states.highContrast.x2.png` | Four steppers, black outlines on white, mid, min, max and disabled. The "−" is dimmed at min and the "+" at max; the disabled one is fully muted but its outline is not |
| `text_field_error.light.x2.png` | A red 2 pt outline, the floating "Email" label in red, `peter@` and the red error text wrapped on two lines |

The four I copied into the evidence folder: `search_field_disabled.light.x2.png`, `chip_group_single.dark.x2.png`, `segmented_german.light.x2.png`, `stepper_states.highContrast.x2.png`.

## Mutations (mine, 10) — [script](verifier/mutations.sh), [log](verifier/mutations.log)
Each replaces exactly one string, runs `inputs_test` and `golden_test` uncached, and restores with `git checkout`; the tree was clean afterwards.

| # | Mutation | Result |
|---|---|---|
| M1 | `LayoutBuilder` back in `boundedFieldWidth` | **killed** by `inputs_test` (the intrinsic-sizing tests) |
| M2 | chip `GestureDetector.onTap` removed (the strip no longer taps) | **killed** by `inputs_test` |
| M3 | search disabled fill `background` → `surface` | **killed** by `golden_test` |
| M4 | stepper clamp drops the max | **killed** by `inputs_test` |
| M5 | the increase button never disabled at max | **killed** by `inputs_test` and `golden_test` |
| M6 | the clear button always shown | **killed** by `inputs_test` and `golden_test` |
| M7 | segment `selected: false` in semantics | **killed** by `inputs_test` |
| M8 | multi-select never removes (add only) | **killed** by `inputs_test` |
| M9 | `onChanged('')` dropped from clear | **killed** by `inputs_test` |
| M10 | chip outer `minHeight` 44 → 30 | **survived, equivalent.** The inner content (`minHeight: 20` + 2×8 pad + 2×4 pad) is 44 at any text scale, so the outer minimum is redundant. Not a test gap in practice |

## Test-integrity audit
- Tests deleted, skipped or weakened: **none.** The package is new. `git diff origin/main` outside `utility/mc_ds_inputs` is the root `pubspec.yaml` (workspace entry), the two new checks, F-0043, the task file and the evidence.
- Lint suppressions added: **none** (`grep ignore:`, `ignore_for_file` and `skip:` over the package: no hits).
- Golden files updated: 160 new, none modified relative to `origin/main`. The 4 `search_field_disabled` ones changed within this branch's review round only (viewed, intended).
- API check against the Outcome: the barrel exports `McTextField`, `McSearchField`, `McChip`, `McChipOption`, `McChipGroup.single` / `.multi`, `McSegment`, `McSegmented`, `McStepper` and `mcFieldUnboundedWidth`, as listed in the Outcome. No signature changed in the review round.
- Every AC has a test whose name contains its ID (AC1: 160 goldens plus the groups; AC2 and AC3 as above; AC4: the check scripts).

## Issues found
None blocking.
1. (Info) `McTextField` and `McSearchField` under `Flexible` take the full available width, not their content width. This is expected for a `TextField` and is documented as "needs a bounded width"; mention it to T-0045 if it lays fields out in loose rows.
2. (Info) Five segments at 2× and 3× break words in narrow cells (the engineer's own follow-up). Seen in `segmented_german`; legal, no overflow.
3. (Info) M10 is an equivalent mutant (above).

## Notes for the Tech Lead
- I ran `fvm flutter pub get --offline` as instructed; it did not change the lockfile or any tracked file (`git status` was clean throughout).
- The Bazel output base `/tmp/mc-ob-T-0044-verifier` was shut down. No simulators were used.
- Verified commit `b0260ce` is the head of `fleet/T-0044-ds-inputs`. This report commit goes on top of it.
