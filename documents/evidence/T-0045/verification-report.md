# Verification report — T-0045: `mc_forms` and `mc_ds_forms` (forms kit)

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, ADR-0011), not the implementer
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0045-forms-kit` @ `20eb7cc`
- **Simulator:** not needed (kit task, no e2e)
- **Verdict:** PASS (one low-severity test gap, no blocking defect)

## Gates re-run independently
Own Bazel output base `/tmp/mc-ob-T-0045-verifier`, shut down at the end.

| Gate | Command | Result |
|---|---|---|
| test //... (kits uncached) | `T-0045-AC4_gates.sh --role verifier` | PASS (123/123) |
| lint | `build --config=lint //...` | PASS |
| mc_arch_check | via gates script | PASS |
| rules_fork check | via gates script | PASS |
| Format | `dart format --set-exit-if-changed` (after `pub get --offline`) | PASS |
| l10n_check | via gates script | PASS |
| Fixtures closure | T-0031-AC6 | PASS |
| Closure and layering | `T-0045-AC4_closure_layering.sh` | PASS |
| Coverage (own check of the script's LCOV union) | `mc_forms` 266/266, `mc_ds_forms` 195/195 | 100 % (>= 90 %) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Really asserts the AC? | Result |
|---|---|---|---|---|
| T-0045-AC1 | rules, composition, cross-field, typed codes | `validators_test` (46 AC1 names), `form_controller_test` | yes. Own probes below. Mutations m1, m2 killed. | PASS |
| T-0045-AC2 | per-step errors, blocked `next` touches, `back`, once, double submit | `wizard_controller_test`, `form_controller_test` | yes. m3, m4, m5, m6, m10 killed. | PASS |
| T-0045-AC3 | Next disabled, errors, busy blocks taps, semantics, goldens | `forms_test`, `golden_test` | yes (one gap, see Issues). m7, m9 killed. | PASS |
| T-0045-AC4 | purity, layering, registered, coverage, gates, `MC_GENERATED_DART` | `purity_test`, both check scripts | yes | PASS |

### Own probes (throwaway test, removed)
- `Validators.pattern`: `a|ab` on "ab" passes and on "abc" fails. `\d+?` on "123" passes. `^a$` with `multiLine` on "a\nb" fails. `dotAll`, `caseSensitive`, `unicode` flags carry over. A pattern with its own `(?<=x)`, `(?<![\s\S])`, `(?=..)`, `(?!..)`, a named group with `\k<n>`, a numbered back-reference `\1`, and `a|b|`: all match as expected. The wrapper uses a non-capturing group, so group numbers don't shift. "a\n" does not match `a$`.
- Grapheme lengths: 10 emoji pass `maxLength(10)` and 11 fail. `e` + combining accent counts 1. The family emoji (joined) counts 1. A flag counts 1. `minLength(2)` of the joined emoji fails.

### TL decision check (blocked Next)
Followed. Next stays disabled (`onPressed` null, semantics `enabled: false`, hint set, no tap action). A tap runs `onBlockedNext`, wired to `touchCurrentStep()`. The error shows and the step does not advance. Submit is the same through `onBlockedSubmit`. Tapping is not wired while completing or busy. An enabled Next keeps its tap action. All covered by tests; m7 (blocked tap callback removed) fails them.

### Goldens
- `bazel run //utility/mc_ds_forms:golden_test -- --update-goldens` from a clean output base wrote 56 goldens. `git status` shows no change: **byte for byte identical**.
- The 8 `form_scaffold_busy.*` goldens that changed: viewed light x1 and highContrastDark x1. The fields show the disabled fill, and the spinner and "Saving" are unchanged. The change is expected.
- Long German labels at 1x, 2x and 3x: no overflow (the tests pass).
- 4 evidence PNGs, 781 px wide, 1000 px high at most (downscaled).

### Mutations (10 of my own, via `scratchpad/mut.sh`, each reverted)
| # | Mutation | Result |
|---|---|---|
| m1 | drop the end anchor `(?![\s\S])` in `pattern` | killed |
| m2 | `maxLength` counts UTF-16 units | killed |
| m3 | `next()` on an invalid step no longer touches | killed |
| m4 | `submit` loses the `isSubmitting` guard | killed |
| m5 | `setValue` accepted while submitting | killed |
| m6 | `complete()` touches every step, not the first invalid one | killed |
| m7 | `McBlockedTap` onTap null | killed |
| m8 | text sync always puts the selection at the end | **SURVIVED** |
| m9 | text sync without the unchanged-value early return | killed |
| m10 | `next()` allowed after completion | killed |

## Test-integrity audit
- Tests deleted, skipped or weakened: none (no deleted files against `origin/main`, no `skip:`).
- Lint suppressions added: none (the only `// ignore` text in the diff is in the Outcome prose).
- Golden files updated: none from an earlier state (56 new, regenerated identical).
- `characters` dependency: no lock changed (`pubspec.lock` and `MODULE.bazel.lock` not in the diff).
- BUILD globs use `MC_GENERATED_DART` (both packages). Diff outside the two packages: workspace `pubspec.yaml` and the two `T-0045-AC4_*` scripts only.
- Layering negative control (mine): `mc_feature_flow: any` added to `mc_ds_forms/pubspec.yaml` only. The script reports it at `pubspec.yaml:19` and exits 1 (FAIL). Reverted.
- Public API matches the Outcome (checked `McFormState.fieldOf<T>`, `touchCurrentStep`, `fromState` with `onBlockedNext` and `blockedHint`, `McFormScaffold.onBlockedSubmit`).

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Busy, light | `form_scaffold_busy.light.x1.png` | disabled fields, spinner, "Saving" | yes |
| Busy, high-contrast dark | `form_scaffold_busy.highContrastDark.x1.png` | same, dark | yes |
| Invalid, disabled save | `form_scaffold_disabled_errors.light.x1.png` | errors under both fields, disabled button | yes |
| Wizard invalid | `wizard_stepper_invalid.light.x1.png` | step indicator, disabled Next | yes |

## Issues found
1. (Low) Mutation m8 survives: no test checks that an external value change keeps a cursor in the middle of the text. The existing "clamped cursor" test only moves the cursor from the end to the end. `utility/mc_ds_forms/lib/src/mc_form_text_field.dart:~96` (the `selection.isValid ? TextSelection(...)` branch). Also, no test names IME composing (the `composing` branch) explicitly. Suggest a follow-up test: set the cursor to 2 in "abcdef", then change the value to "abcdeg", and expect the cursor at 2.
2. (Trivial) The `utility/mc_ds_forms/BUILD.bazel` header comment names `T-0045-AC4_layering.sh`, but the file is `T-0045-AC4_closure_layering.sh`.

## Notes for the Tech Lead
- No blocking defect. Both low items can go to `pending-work.md`.
- The gates script exits 0 correctly when run through a backgrounded wrapper. I checked the written report, not just the exit code.
