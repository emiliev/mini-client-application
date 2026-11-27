# T-0058: `mc_ds_overlays`: dialogs, bottom sheets, menus, tooltips, toasts (U33)

| Field | Value |
|---|---|
| Status | In Verification (Engineer handed off) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (DS widgets; ADR-0011) |
| Branch | `fleet/T-0058-ds-overlays` |
| Created | 2026-11-27 |
| Depends on | T-0019 (DS foundation), `mc_ds_buttons`, `mc_ds_layout`, `mc_ds_theme` |
| Related | plan 01 U33, ST+ and IX+ sets (P1-22 `settings_appearance`, P1-23 `trivia_quiz`); T-0044 (DS kit conventions, goldens, semantics), F-0043 (`LayoutBuilder` breaks intrinsic sizing in dialogs); T-0048, T-0054 (results under overlays) |

## Goal
The ST and IX exemplars need confirm dialogs, choice sheets, menus and transient feedback. Today the only overlay is `app_core`'s hand-rolled `fixture_sign_in_sheet.dart`. Provide one DS family so that features never call `showDialog` or `showModalBottomSheet` directly.

## Scope
- **In: `utility/mc_ds_overlays` (UI)**
  - **Dialogs.** `McDialog` has a title, a body, and 1–3 actions with one primary and an optional destructive action.
    - `showMcConfirm(context, {title, message, confirmLabel, cancelLabel, destructive})` returns `Future<bool>`. It returns `false` on cancel, barrier tap or system back, and never null.
    - `showMcDialog<T>` is the general form.
  - **Bottom sheets.**
    - `McSheet` has a drag handle, a title, a scrollable body and a safe-area inset.
    - `showMcSheet<T>`.
    - `showMcChoiceSheet<T>(options, selected)` returns the picked value, or null if dismissed. It is single-select and shows a check on the current option.
  - **Menus.** `McMenuButton<T>` takes items with an icon, a label, an enabled flag and an optional destructive style. It reports the picked value.
  - **Tooltip.** `McTooltip`: long-press and hover, with a semantics label.
  - **Toasts.** `showMcToast(context, message, {action})`.
    - It is a DS-styled SnackBar with an optional single action.
    - A new toast replaces the current one.
    - It is announced to VoiceOver as a live region.
    - Its duration is longer when there is an action.
  - **Every overlay:**
    - uses the root navigator by default (it covers the flow), with an option for the nearest one;
    - honours text scale up to 2×, with no overflow;
    - has semantics labels and tap targets of at least 44 pt;
    - passes `meetsGuideline` in all 4 themes;
    - never uses `LayoutBuilder` inside an intrinsic-sized dialog (F-0043).
  - **Migration.** Move `app_core`'s `fixture_sign_in_sheet.dart` onto `McSheet` without changing its behaviour. The T-0039, T-0041 and T-0048 sign-in tests must stay green and unchanged.
  - **Goldens.** 4 themes × 2 text scales through `mc_test_utils`. Include long German strings.
  - **Test steps.** Add generic BDD steps to `mc_test_steps`:
    - `I confirm the dialog`
    - `I cancel the dialog`
    - `I choose {option} in the sheet`
    - `the toast {text} is shown`
- **Out:** date and time pickers, full-screen modals, popovers anchored to arbitrary widgets.

## Acceptance criteria
- **T-0058-AC1:** Goldens for every overlay and state (default, destructive, disabled item, selected choice, long text) in 4 themes × 2 scales. There is no overflow at 2×, and none in a 3× probe test.
- **T-0058-AC2:** Behaviour.
  - `showMcConfirm` returns `true` on confirm. It returns `false` on cancel, a barrier tap and system back. Each of the four is tested, and none returns null.
  - `showMcChoiceSheet` returns the tapped value, null on a swipe-down or barrier tap, and shows the current selection.
  - A menu ignores disabled items.
  - A second toast replaces the first.
  - The toast action fires once.
  - With a nested navigator, the root-navigator default covers the nested navigator, and the nearest-navigator option stays inside it.
- **T-0058-AC3:** Semantics.
  - Dialogs are announced with their title as a route name.
  - Sheets have a dismiss label.
  - The toast is a live region.
  - Every tap target is at least 44 pt.
  - `meetsGuideline` passes in all themes.
- **T-0058-AC4:** Migration and steps.
  - The sign-in sheet uses `McSheet`, and every existing sign-in test is green without edits.
  - The four BDD steps exist, each with a negative control.
  - No feature or `app_core` code calls `showDialog`, `showModalBottomSheet` or `ScaffoldMessenger.showSnackBar` directly. Add a grep check to the gates script.
- **T-0058-AC5:** Layering and gates.
  - No dependency on `mc_feature_flow` or `mc_paging`. Extend the layering check.
  - The package is registered and coverage is ≥ 90 %.
  - The 50-run flake check passes on new test targets that involve animations or timers.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format (only the gated directories, P-111) pass.
  - Globs use `MC_GENERATED_DART`.
  - The mini_client e2e passes on your own simulator (the sign-in sheet journeys). Delete the simulator afterwards.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Sonnet) built `utility/mc_ds_overlays`, moved the sign-in sheet onto `McSheet` (its tests run unedited), added the four BDD steps, the no-direct-overlay check, the layering and gates scripts, a mutation script and a 50-run flake script. Handed off.

## Outcome
**Status:** Done, ready for verification. Branch `fleet/T-0058-ds-overlays`. Finding [F-0058](../findings/F-0058-ds-overlays.md). No ADR. `pubspec.lock` and `MODULE.bazel.lock` did not change.

### Public API
Barrel `package:mc_ds_overlays/mc_ds_overlays.dart`. The design system has no localisation, so every accessible name and visible label is a parameter. Every `show...` takes `useRootNavigator = true` (the nearest navigator on request) and `McMenuButton` takes it as a field.
- **Dialogs.** `McDialog({required title, required body, required actions})` (1 to 3 `McDialogAction({label, onPressed, kind = normal | primary | destructive, key})`; a null `onPressed` disables). `showMcDialog<T>(context, {builder, useRootNavigator, barrierDismissible, barrierLabel})` answers the popped value or null. `showMcConfirm(context, {title, message, confirmLabel, cancelLabel, destructive, useRootNavigator, barrierLabel})` answers `Future<bool>`: `true` on confirm, `false` on cancel, barrier tap and system back, never null. Keys `mcConfirmButtonKey` and `mcCancelButtonKey` mark its buttons (the BDD steps use them).
- **Sheets.** `McSheet({title, dismissLabel, child})`: drag handle (a 44 pt dismiss button named `dismissLabel`, closes through `maybePop`), then title and body scrolling together, then the bottom safe-area inset. `showMcSheet<T>(context, {builder, useRootNavigator, isDismissible, enableDrag, dismissLabel})`. `showMcChoiceSheet<T>(context, {title, dismissLabel, options (McChoiceOption(value, label, icon)), selected, useRootNavigator})` answers the tapped value or null. `McChoiceList<T>` is the rows, public for reuse.
- **Menu.** `McMenuButton<T>({items (McMenuItem(value, label, icon, enabled, destructive)), onSelected, semanticLabel, icon, useRootNavigator})`.
- **Tooltip.** `McTooltip({message, child})`: long press and hover.
- **Toast.** `showMcToast(context, message, {action (McToastAction(label, onPressed)), duration})`: replaces the current toast at once, `mcToastDuration` 4 s, `mcToastActionDuration` 8 s, the action fires once and closes the toast.
Layering: depends on `mc_ds_buttons`, `mc_ds_layout`, `mc_ds_theme`, `mc_ds_tokens`; never `mc_feature_flow` or `mc_paging`; no `LayoutBuilder`.

### AC to evidence
| AC | Evidence |
|---|---|
| AC1 | `utility/mc_ds_overlays/test/golden_test.dart`: 15 components x 4 themes x 2 scales = **120 goldens** (dialog default, destructive, three actions with a disabled one, long German; sheet default and long; choice sheet with a selection, with none, long; menu open (default, destructive, disabled item) and long; tooltip shown; toast, toast with action, long toast with action), all looked at. `overlays_test.dart` "T-0058-AC1 no overflow": every scenario (dialog, destructive dialog, sheet, choice sheet, menu, toast, toast with action) with long German text at **1x, 2x and 3x in all 4 themes** (84 tests), plus a dialog and a sheet with a 30-line body at 3x on a short screen (they scroll), `McDialog` and `McChoiceList` under `IntrinsicWidth` and `IntrinsicHeight`, and the sheet's bottom inset |
| AC2 | `overlays_test.dart` "T-0058-AC2 ...": `showMcConfirm` true on confirm, false on cancel, barrier tap and system back (each its own test), destructive style; `showMcDialog` value, null on dismiss, non-dismissible, disabled actions, 1 to 3 actions; `showMcChoiceSheet` tapped value, the current value again, null on swipe down, barrier tap, system back and the handle, check on the current option only, selected announced; menu reports the pick, ignores a disabled item (menu stays open), reports nothing on dismissal, destructive and disabled styling; toasts replace each other at once, the action fires once (two taps) and closes the toast, 4 s against 8 s, explicit duration, controller close; **root and nearest navigator for dialog, confirm, sheet, choice sheet and menu** (default is the root navigator, nested navigator untouched, barrier covers the screen; the option keeps the overlay inside the 300 pt nested navigator) |
| AC3 | `overlays_test.dart` "T-0058-AC3 ...": dialog scopes and names its route with the title and the title is a heading; sheet names its route, the handle is a dismiss button with a tap action, the barrier carries the label (also the dialog's); toast is a live region; menu button named and openable by the semantics tap action, disabled row announced as disabled with no tap action; tooltip on the child's semantics, shows on long press and on hover, not on a tap; tap targets at least 44 pt at 0.5x and 1x (menu button and rows, confirm, cancel and destructive buttons, choice rows, the handle, the toast action); `meetsGuideline` (tap target, labelled target, text contrast) for 7 scenarios x 4 themes (28 tests) |
| AC4 | The sign-in sheet is `McSheet` (`fixture_sign_in_sheet.dart`); `sign_in_sheet_test` and all of `app_core`'s tests pass **unedited**, and the e2e sign-in journeys pass ([evidence](../evidence/T-0058/engineer/mini_client/e2e-summary.md); `14_sign_in_sheet.png`, `31_sign_in_sheet.png`). `utility/mc_test_steps/test/overlay_steps_test.dart`: the four steps (`I confirm the dialog`, `I cancel the dialog`, `I choose {option} in the sheet`, `the toast {text} is shown`) each with negative controls (nothing open, wrong or partial text, two identical options, replaced toast, expired toast). `tool/checks/T-0058-AC4_no_direct_overlays.sh` ([report](../evidence/T-0058/engineer/ac4-no-direct-overlays.md)): no `showDialog`, `showModalBottomSheet`, `showSnackBar` (and 5 relatives) in any `lib/` outside `mc_ds_overlays`; positive control and 9 negative controls; part of the gates script |
| AC5 | `tool/checks/T-0058-AC5_layering.sh` ([report](../evidence/T-0058/engineer/ac5-layering.md)): re-runs T-0044-AC4 (and so T-0040-AC3), neither forbidden package in the closure of the library or either test target, positive control, 10 negative controls. `tool/checks/T-0058-AC5_gates.sh` ([report](../evidence/T-0058/engineer/ac5-gates.md)): `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, provenance, fixtures closure, no-direct-overlay check, layering and coverage all PASS; **coverage `mc_ds_overlays` 99.6 % (233/234, after the review round)**. Flake check `--runs_per_test=50 --nocache_test_results` on `overlays_test`, `golden_test`, `overlay_steps_test` and `sign_in_sheet_test`: 0 failures ([log](../evidence/T-0058/engineer/flake-50.log)). e2e on `mc-T-0058-engineer-93863` (deleted): `reading_list_journey`, `comics_journey`, `reading_list_deeplink` PASS |

Mutations ([script](../evidence/T-0058/engineer/mutations.sh), [log](../evidence/T-0058/engineer/mutations.log)): **72 of 72 killed, 0 survived, 0 broken** (dialog and confirm return values, root against nearest navigator for all five overlays, toast replacement, duration and single action, disabled menu items, semantics, tap targets, the goldens, the four steps and the sign-in sheet). The first run found 11 survivors; the cause was in the tests each time (see F-0058 facts 16 to 19): helpers that passed the default they were testing (4 survivors), a duration test that pumped too coarsely, a tap-target test that measured the barrier instead of the handle, a step test with no duplicate options, and a redundant `liveRegion` wrapper (removed). Three were equivalent mutants (Material pads a button to 48 pt) and were dropped, with the reason in the script header.

### Test integrity
New package; nothing deleted, skipped or weakened; no `// ignore:`; no existing golden changed. The sign-in tests are unedited. The goldens use a local copy of `mcGoldenMatrix` (real shadows, F-0058 fact 9).

### Changes outside the package
- `app/wiring/app_core`: `fixture_sign_in_sheet.dart` (now `showMcSheet` and `McSheet`), `BUILD.bazel`, `pubspec.yaml` (`mc_ds_overlays`). Justified by the migration in the scope.
- `utility/mc_test_steps`: 4 step files and the barrel, a test target and the `mc_ds_overlays` dependency (the steps find the confirm keys and `McSheet`).
- Root `pubspec.yaml`: workspace list.
- New check scripts under `tool/checks/` (`T-0058-AC4_no_direct_overlays.sh`, `T-0058-AC5_layering.sh`, `T-0058-AC5_gates.sh`); no existing script changed.

### Decisions
- **Toast and the navigator.** A toast is not a route: it is shown by the nearest `ScaffoldMessenger`, which in the app is the root one. There is no `useRootNavigator` for it.
- **Destructive is outlined,** not filled, because the brand primary is red too (F-0058 fact 10).
- **The toast action is our own `TextButton`,** not a `SnackBarAction` (overflow at large text, F-0058 fact 2).
- **`McSheet` needs a bounded height** (a route or a `Scaffold` body gives one): its body is a `Flexible` scroll view.
- **The sheet's handle is a button** (44 pt, `maybePop`): the dismiss action for screen readers; the sign-in sheet's `PopScope` still holds while busy.
- **The sign-in sheet's dismiss label is "Close"** (English only, like the rest of the stand-in).

### Follow-ups
- A real `settings_appearance` feature can use `showMcChoiceSheet` as is; `trivia_quiz` can use `showMcConfirm` and `showMcToast`.
- Android tap targets (48 dp) and the popup menu's behaviour on Android are not checked (iOS first).
- `McMenuButton` is an icon button only; a text trigger would need a `child` option.

## Review round (after `/code-review`)
`origin/main` merged first (docs only). No public signature changed; `mcGoldenMatrix` got an optional parameter.
1. **Keyboard (important).** `McSheet` pads its bottom by `viewInsets` (outside the card, so the card sits on the keyboard) and drops its safe-area bottom while the keyboard is up; the body stays a scroll view in a bounded column. Tests "T-0058-AC1 keyboard": a sheet with a `TextField` and two buttons under a 300 pt keyboard (field and Save above it, hit-testable, the card sits on the keyboard, typing works), at 2x and 3x nothing overflows and `scrollUntilVisible` reaches Save, and with no keyboard the card is flush with the bottom.
2. **Handle on a non-dismissible sheet (important).** `showMcSheet` wraps the builder in a private `InheritedWidget` (`dismissible: isDismissible && enableDrag`); when false the handle is a picture (no tap, `ExcludeSemantics`). Tests: with `isDismissible: false` and with `enableDrag: false` the handle tap leaves the sheet open, no dismiss button exists for a screen reader, and (for `isDismissible: false`) the barrier tap is ignored; the dismissible case and a standalone `McSheet` keep the handle. The sign-in sheet's `PopScope` behaviour is unchanged (its tests are unedited and green).
3. **AC4 grep.** Added `showAdaptiveDialog`, `showCupertinoSheet`, `showMaterialBanner`, `showAboutDialog`, `showLicensePage`, the `PopupMenuButton` widget and `Overlay.of(...).insert` (with `showCupertinoDialog` and `showCupertinoModalPopup` already in); 15 negative controls plus the comment control; no lib outside `mc_ds_overlays` hits.
4. **Titles read twice.** The card scopes the route; the title's own node is the heading **and** names the route (`header` and `namesRoute` on one `Semantics`). Test `_expectTitleOnce` (dialog and sheet): exactly one node carries the title, it is a heading, it names the route, and an ancestor scopes it.
5. **Choose step.** Looks only inside `McChoiceList`. Tests: a sheet titled "Dark" with a "Dark" row picks the row; a non-choice sheet with "Dark" and "Light" text is red.
6. `app_core/pubspec.yaml`: `mc_ds_overlays` after `mc_ds_media`.
- **Golden harness.** The local copy is gone. `mcGoldenMatrix(realShadows: true)` in `mc_test_utils` (default false, `debugDisableShadows` restored in a `finally`). `test //...` (every package's goldens) passes unchanged.
- **Goldens changed: none of the 120 existing ones** (regenerated byte for byte). **Added 8:** `sheet_keyboard.{light,dark,highContrast,highContrastDark}.{x1,x2}` (a sheet over a 300 pt stand-in keyboard, the new inset behaviour).
- **Mutations** (added for items 1, 2, 4, 5 and the shadow option; four patterns refreshed after formatting; one test strengthened after a survivor): REVIEW_MUTATION_PLACEHOLDER. Gates PASS (181 tests, coverage 99.6 %), 50-run flake check 0 failures, sign-in e2e REVIEW_E2E_PLACEHOLDER.
