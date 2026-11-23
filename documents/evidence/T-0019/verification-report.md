# Verification report — T-0019: Design-system foundation

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0019-design-system` @ **`19705dc`**, the round-3 fixes (re-verification on `fleet/T-0019-verify2`). Round 1 was `e11da43` on `fleet/T-0019-verify` (report `7e1bc14`, FAIL); it is kept below as history.
- **Simulator:** none (the task is package-level: widget and golden tests only, no app or E2E)
- **Bazel:** `tool/bazelw --output_base=<verifier scratchpad>/ob` (own output base; the shared disk cache is still used, as `.bazelrc` sets)
- **Verdict:** **PASS** at `19705dc`. All four ACs pass, and the round-1 Issues 1, 2 and 4 are fixed (see "Re-verification at 19705dc"). The round-1 verdict at `e11da43` was FAIL (Issue 1).

## Re-verification at 19705dc
What changed since `e11da43`: `mc_icon_button.dart` (+ tests), the loading golden gets a `settle` of 700 ms (harness parameter, 8 loading PNGs regenerated), and `McPalette` gets `==` / `hashCode` (+ test). No tests were deleted or weakened. The old test `icon button announces its label once` was replaced by a strictly stronger `T-0019-AC2 buttons: one node has label, button flag and tap` (`matchesSemantics`) plus a disabled-state test.

| Check | How | Result |
|---|---|---|
| Tests, uncached | `tool/bazelw test --nocache_test_results` over the 6 package globs | 10/10 targets PASSED, 87 cases (buttons 7, tokens 6) |
| Lint | `tool/bazelw build --config=lint //utility/...` | clean, exit 0 |
| AC2 `McIconButton`, my own check | scratch test (deleted afterwards) that walks the semantics tree and calls `tester.getSemantics(find.byType(IconButton))` | Exactly **one** node contains "Close": `SemanticsNode#4 label: "Close", flags: isButton, hasEnabledState, isEnabled, actions: tap`, with 0 children. It is the same node `getSemantics(IconButton)` returns. The semantics tap action fires `onPressed` once, and a pointer tap fires it once more. **PASS** |
| Loading goldens | viewed `loading.light.x1.png` and `loading.highContrastDark.x2.png` | A clear ~3/4 spinner arc in the palette colour (red `#B3131B` on light, pink on black), no longer a dot. Files are ~5.2 KB, up from 2.4 KB. **PASS** |
| Loading determinism | `run //utility/mc_ds_feedback:golden_test -- --update-goldens` twice | 24 written per run; `shasum` identical to the committed files both times (the fake clock makes the frame deterministic) |
| `McPalette` equality | code review + `tokens_test` `T-0019-AC1 tokens: McPalette has value equality` | `==` compares all 12 fields (`listEquals`), and `hashCode = Object.hashAll` over the same fields, so they are consistent. `lerp(light, dark, 0) == light` passes. **PASS** |

Residual nit (non-blocking): because `excludeSemantics: true` drops `IconButton`'s own node, the merged node no longer carries `isFocusable` / the `focus` action that `IconButton` had. VoiceOver navigation on iOS is unaffected. Consider `focusable: true` (or `MergeSemantics` instead of `excludeSemantics`) for Android/web keyboard a11y later.

Still open (TL, for `pending-work.md`): round-1 Issue 3 (Inter in the Bazel app bundle), plus the P3-06 visibility restriction, moving `mc_ds_testing` into `mc_test_utils`, and `mc_l10n_core` strings.

Evidence added: `verifier/loading.light.x1.png` (750x440).

---

# Round 1 (e11da43): FAIL, kept for history

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Tests | `tool/bazelw test --nocache_test_results //utility/mc_ds_tokens/... //utility/mc_ds_theme/... //utility/mc_ds_layout/... //utility/mc_ds_buttons/... //utility/mc_ds_feedback/... //utility/mc_ds_testing/...` | 10/10 targets PASSED, 85 test cases (tokens 5, theme 6, theme goldens 8, layout 5, layout goldens 16, buttons 6, buttons goldens 8, feedback 5, feedback goldens 24, fonts 2) |
| Lint | `tool/bazelw build --config=lint //utility/...` | clean, exit 0 (17 targets) |
| Format | `fvm dart format --output=none --set-exit-if-changed utility` | 31 files, 0 changed |
| Lockfile | `fvm flutter pub get --enforce-lockfile` | exit 0; `pubspec.lock` unchanged |
| Golden mismatch (mine) | `McPalette.light.surfaceVariant` `0xFFE9E9EC` -> `0xFFE9E9ED` (a 1-unit change), then the 4 golden targets | 8 goldens FAIL, exactly the light variants that use `surfaceVariant`: theme_sheet light x1/x2 (`Pixel test failed, 2.07%, 11169px diff`), adaptive_grid_375/1024 light x1/x2, buttons light x1/x2. Feedback (does not use the token) still passes. Reverted; tree clean. |
| Determinism | `tool/bazelw run //utility/mc_ds_{theme,layout,buttons,feedback}:golden_test -- --update-goldens`, twice | 56 goldens written per run. `shasum` is identical for committed, run 1 and run 2. Tree clean afterwards. |
| L4 E2E | n/a | No app in scope (`ds_catalog` is P1-12) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0019-AC1 | component x light/dark/HC (+HC dark) x scale 1.0/2.0, real fonts | `golden_test` in theme, layout, buttons and feedback (56 goldens = 7 components x 4 variants x 2 scales, names `T-0019-AC1 <component> golden <variant> x<n>`); `fonts_test` (registered family == `packages/mc_ds_theme/Inter`; Inter width != Ahem width) | yes. I viewed 8 PNGs myself: real Inter (proportional, correct weights 400/500/600/700), MaterialIcons glyphs (search, close, plus, error_outline, inbox) render, and text at 2.0 reflows (wrapping, not clipping). The 1-unit mismatch proves pixel-exact comparison. | PASS (see Issue 2: the loading golden is weak) |
| T-0019-AC2 | `McErrorView` Retry fires once; semantics label exists | `feedback_test`: `T-0019-AC2 Retry fires onRetry exactly once`, `... error view has a semantics label`, `... custom retry label and title are honoured` | yes for `McErrorView`. My own scratch test (deleted) confirmed: 1 node labelled `Error: Something went wrong. Network down`, 1 `Retry` node; tap -> 1, then semantics tap action -> 2. | **FAIL on the `McIconButton` check** (Issue 1). The `McErrorView` part passes. |
| T-0019-AC3 | 2 columns at 375, 4 at 1024 | `layout_test`: `T-0019-AC3 grid shows 2 columns at width 375`, `... 4 columns at width 1024` (checks `crossAxisCount` and tile row positions), breakpoint edges 599/600/1023/1024, `... grid in unbounded width falls back to the screen` (horizontal scroll, 1024 screen -> 4, no exception); goldens `adaptive_grid_375` / `_1024` | yes. Viewed: 375 shows 2 columns, 1024 shows 4. | PASS |
| T-0019-AC4 | gates green, goldens deterministic over 2 runs | gates above | yes | PASS |

## Test-integrity audit
- Tests deleted, skipped or weakened: none. Branch history (`44a05e3`, `e11da43`) only adds tests.
- Lint suppressions added: none (`grep -r "ignore:" utility` finds none).
- Golden files updated: 56 new goldens (no existing goldens before this task).
- **False positive:** `buttons_test` `T-0019-AC1 buttons: icon button exposes its semantic label` and `... announces its label once` pass, but neither asserts that the labelled node is the button. See Issue 1.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| theme light, scale 2.0 | `verifier/theme_sheet.light.x2.png` (downscaled to 592x1200) | Inter Display/Title/Headline/Body/Caption with correct weights; body wraps at 2.0; primary/surface/variant/error swatches | yes |
| error view HC dark, scale 2.0 | `verifier/error_view.highContrastDark.x2.png` (592x1200) | black background, pink `error_outline` icon, bold white title (wraps), light-grey body, pink Retry with black text | yes |
| grid 1024 dark, scale 2.0 | `verifier/adaptive_grid_1024.dark.x2.png` (1200x398) | 4 columns x 2 rows, "Tile 1..8" in Inter | yes |
| also viewed (not copied) | theme_sheet.dark.x2, buttons.highContrast.x2, adaptive_grid_375.highContrast.x2, empty_view.highContrastDark.x1, loading.light.x2 | dark/HC palettes applied; buttons (Primary, Secondary, Tertiary, two disabled) and 3 icon buttons; 2-column grid at 375; inbox icon + text; loading shows only a red dot | yes, except the loading golden (Issue 2) |

## Conformance and hygiene
- **Font licence:** `utility/mc_ds_theme/assets/fonts/OFL.txt` (SIL OFL 1.1, Inter copyright line) is bundled and recorded in `utility/mc_ds_theme/README.md` (source rsms/inter 4.0). The TTF name tables read `Copyright 2016 The Inter Project Authors`, version `4.000;git-a52131595`: genuine Inter.
- **App-resolution fix:** `McTypeScale` styles carry `fontFamily: 'Inter', package: 'mc_ds_theme'` (resolves to `packages/mc_ds_theme/Inter`). `ThemeData` passes `fontFamily` + `package`. `mcLoadFonts()` registers `FontLoader(mcRegisteredFontFamily)` with `mcRegisteredFontFamily = mcResolvedFontFamily = 'packages/mc_ds_theme/Inter'`. `fonts_test` guards both the names and the rendering. My mismatch and viewing confirm the goldens use Inter.
- **No `flutter_test` in production:** `bazel query 'rdeps(//utility/..., @pub_deps//:flutter_test, 1)'` returns only test targets plus `//utility/mc_ds_testing:mc_ds_testing`. `rdeps(//utility/..., //utility/mc_ds_testing)` returns only the 4 `golden_test` targets and `fonts_test`. Pubspec `dependencies:` of tokens/theme/layout/buttons/feedback hold no `flutter_test`.
- **`mc_ds_testing` is `testonly = True`** (`bazel query 'attr(testonly, 1, //utility/...)'` lists it with the test targets).
- **Visibility:** `//visibility:public` in all 6 packages, with a BUILD comment "Public until the P3-06 package_group exists (follow-up: restrict to layers)", plus F-0014 Implications and the task Outcome. It is not yet in `pending-work.md` (TL-owned).
- **Binaries:** 67 binary files, nothing besides fonts and PNGs. Fonts: Inter-Regular 407,056 B, Medium 411,500, SemiBold 413,976, Bold 415,072 (1.65 MB total). Goldens: 56 files, 1,822,975 B total, largest 80,165 B. Engineer evidence: 7 PNGs, 29,968 to 140,159 B, all ≤ 1200 px. Verifier evidence: 3 PNGs (43 to 121 KB), ≤ 1200 px.
- **Root changes:** only `pubspec.yaml`, with 6 `workspace:` entries. The 6th, `mc_ds_testing`, is beyond the 5 the task scope named; it is documented in the Outcome. No change to `MODULE.bazel`, `MODULE.bazel.lock`, `BUILD.bazel`, `.bazelrc` or `pubspec.lock`.
- **High-contrast palettes:** I computed WCAG ratios. Every text pair in `highContrast` / `highContrastDark` is ≥ 9.9:1, so the documented 7:1 holds.
- **Plan 01 catalogue:** dependencies match U23 to U27. Exceptions: buttons/feedback also depend directly on `mc_ds_tokens` (also transitive), and feedback lacks `mc_l10n_core` (does not exist yet; strings are parameters with English defaults, documented). Names are namespaced (`McErrorView`, not `Error`), per research §4.6. Toggles (U26), skeletons/toasts/banners (U27) are not built (foundation scope).

## Issues found
1. **(Major, accessibility; blocks AC2) `McIconButton`'s accessible name is on a non-actionable wrapper node, not on the button.** `McIconButton` wraps `IconButton` in `Semantics(label: semanticLabel)` without merging. The `IconButton` creates its own button node, so the semantics tree is:
   ```
   SemanticsNode#4   label: "Close"                      (no actions)
   └─SemanticsNode#5 actions: focus, tap                 (no label)
                     flags: isButton, hasEnabledState, isEnabled, isFocusable
   ```
   VoiceOver would stop at a static "Close", then at an unlabelled "Button". Double-tapping "Close" does nothing. This breaks WCAG 4.1.2 (the button has no name). The two existing icon-button tests pass only because exactly one node contains "Close". They never check that this node is the button.
   **Repro** (in any test in `utility/mc_ds_buttons/test/`):
   ```dart
   final h = tester.ensureSemantics();
   await tester.pumpWidget(MaterialApp(theme: McTheme.light, home: Scaffold(body:
       McIconButton(icon: Icons.close, semanticLabel: 'Close', onPressed: () {}))));
   final s = tester.getSemantics(find.byType(IconButton));
   expect(s.label, 'Close');                                        // fails: ''
   expect(s.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
   h.dispose();
   ```
   **Fix I checked:** wrap the result in `MergeSemantics` (`MergeSemantics(child: Semantics(label: ..., child: Tooltip(... IconButton ...)))`). Then `getSemantics(find.byType(IconButton))` gives `label="Close"` with the tap action. Replace or extend the two tests with `matchesSemantics(label: 'Close', isButton: true, hasTapAction: true, isEnabled: true, hasEnabledState: true, isFocusable: true)`. Regenerating the goldens should not be needed (semantics do not paint), but re-run them.
2. **(Minor, non-blocking) The `loading` goldens capture an almost empty frame.** The indeterminate `CircularProgressIndicator` at t=0 draws only a ~8 px red dot (`loading.*.png`, about 2.4 KB each; x1 and x2 are byte-equal in size because there is no text). The goldens still catch colour changes but not stroke or size regressions. Suggestion: `pump(const Duration(milliseconds: 400))` before matching, or use a determinate `value` in the golden.
3. **(Minor, follow-up) The Bazel app bundle lacks Inter.** Only the pubspec `flutter: fonts:` declaration exists. F-0014 Implications notes this, but it is not in `pending-work.md`.
4. **(Nit) `McPalette` has no `==` / `hashCode`.** `theme_test` compares palettes by identity of the `const` instances. A lerped or copied palette would never compare equal.

## Notes for the Tech Lead
- Only Issue 1 blocks the verdict. It is a small, local fix in `utility/mc_ds_buttons/lib/src/mc_icon_button.dart` plus a stronger test. Re-verification only needs the buttons targets, the lint run and a quick look at the semantics tree.
- Please add to `pending-work.md`: the P3-06 visibility restriction (Issue 3 context), Inter for the Bazel app bundle (Issue 3), moving `mc_ds_testing` into `mc_test_utils`, and `mc_l10n_core` strings for `McErrorView` / `McLoading` / `McEmptyView`.
- My scratch tests (`zz_verifier_*_test.dart`) were deleted. Each mutation was reverted and `git status` was clean before this commit. Ignored `.dart_tool/` directories exist from `pub get`.
