# T-0058: `mc_ds_overlays`: dialogs, bottom sheets, menus, tooltips, toasts (U33)

| Field | Value |
|---|---|
| Status | In Progress |
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
