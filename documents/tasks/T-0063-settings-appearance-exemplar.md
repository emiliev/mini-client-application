# T-0063: `settings_appearance` exemplar (ST archetype), P1-22

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: first ST exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar) |
| Branch | `fleet/T-0063-settings-appearance` |
| Created | 2026-11-27 |
| Depends on | T-0061 (identity preferences routes), T-0058 (`mc_ds_overlays`), T-0044 (`mc_ds_inputs`: `McSegmented`), T-0040 (DS navigation), T-0052 (`mc_feature_flags`), T-0053/T-0056 (analytics, ADR-0012), T-0039/T-0050 (session epoch, `authPinned`) |
| Related | plan 01 F056, P1-22 (EX-AC1–5, AC6: "when dark mode is chosen, the whole app re-themes and the choice survives a restart (fixture identity sync)"), §3.3, §4, §6.1 (ST: 2 pages, 1–2 blocs, 2 endpoints, 1 nav method); ADR-0007, ADR-0010, ADR-0011, ADR-0012; F-0056, F-0061; `McThemeModeController` (`mc_ds_theme`), `McApp(themeMode:)` (`app_core`) |

## Goal
The sixth archetype exemplar, **settings (ST)**: `feature/settings/settings_appearance`. You choose the theme mode (System, Light or Dark), the density (Comfortable or Compact) and Reduce motion. The **whole app** applies the change at once. The choice is kept on the device, and when you are signed in it follows you through the identity preferences routes.

As with the five merged exemplars, this package is the shape the P1-24 bricks copy for every ST feature (`settings_accessibility`, `settings_notifications`, `settings_language`, and others). It must match the established exemplar shapes, with no workarounds.

## Scope
- **In:**
  - **App-wide appearance state lives outside the feature.**
    - Add a small utility, `utility/mc_appearance` (UF), or extend an existing one if that fits plan 01 better. Justify the choice in an ADR draft if it is costly to reverse.
    - It holds the current `AppearancePreferences` (theme mode, density, reduce motion).
    - It persists them locally in `mc_storage`, which is the source of truth when signed out.
    - When signed in, it syncs with `GET/PATCH /v1/me/preferences`:
      - Writes use `ifVersion` and `authPinned` on the session epoch (F-0050).
      - On a 409, re-apply only the user's change on top of the returned `current` and retry once.
      - On sign-in, the server's values win unless there is a local change not yet synced. Decide the rule and document it.
      - On sign-out, keep the last values locally.
      - Pin the session-epoch rule: check after every await, before a write.
    - `McApp` takes its `ThemeMode` from it, so the whole app re-themes without a restart. Density and reduce motion are exposed so the DS and features can read them. At minimum, `McTheme`'s visual density and a `MediaQuery`-level disable-animations override for reduce motion. Document what each one affects.
  - **`feature/settings/settings_appearance`.**
    - `SettingsAppearanceFlow`, with 2 pages: the appearance page, and an "About themes" explainer reached in the flow.
    - `SettingsAppearanceNavigator` with `requestSignIn()`, for a "Sync across devices" call-to-action shown when signed out.
    - One bloc with a freezed state: `loading`, `ready` (values, sync status `synced`/`pending`/`offline`/`conflictResolved`), `failure`.
    - UI:
      - `McAppBar` with `McFlowBackButton`;
      - `McSegmented` for theme mode and for density;
      - a switch row for reduce motion;
      - a sync status line;
      - an `McSheet` "Reset to defaults" confirm, via `showMcConfirm`.
    - l10n in en and de.
    - BDD, contract tests and goldens (R6).
    - Analytics per ADR-0012: `settings_changed` with `setting` and `value`, plus screen names `settings_appearance` and `settings_appearance_about`.
  - **`app/wiring/account_wiring`.**
    - The `/settings/appearance` route under home (`nestUnderHome`).
    - `AccountRouteTargets`.
    - The navigator implementation, with sign-in as in the other wirings.
    - `AppLocations.settingsAppearance`, plus a drift test.
  - **`mini_client`.**
    - A Settings entry on home.
    - The deep link `miniclient://app/settings/appearance`.
- **Out:** `settings_home` (the index), accessibility, language, notifications, and `account_sandbox` (follow-up).

## Acceptance criteria
- **T-0063-AC1 (EX-AC1).** Given the defaults, when I open Appearance, I see System, Comfortable and Reduce motion off. Given signed in as `u-101`, I see Dark (the server seed). BDD.
- **T-0063-AC2 (EX-AC2).**
  - Given `identity.preferences_error` while signed in, the page still shows the local values, the sync status says offline, and Retry syncs.
  - Given `identity.preferences_conflict`, a change is re-applied on the new version and ends `synced`, with exactly 2 PATCHes.
  - Errors never block a local change.
  - BDD with request counts.
- **T-0063-AC3 (EX-AC3).**
  - The explainer opens in the flow.
  - Signed out, "Sync across devices" awaits `requestSignIn()`. On `true` the values sync per the documented rule.
  - Reset asks via `showMcConfirm`. Cancel changes nothing. Confirm restores the defaults and syncs them.
  - The wiring test pushes the location.
- **T-0063-AC4 (EX-AC4).**
  - With locale `de`, every string is German.
  - With `en_XA`, nothing overflows at 1× and 2× text scale.
  - Goldens in all 4 themes. Compact density must visibly differ from comfortable.
- **T-0063-AC5 (EX-AC5).** The mini_client e2e on your own simulator:
  - home → Settings → Dark: **the home page and another feature, for example the characters list, render dark** (screenshots);
  - kill and relaunch: still Dark;
  - signed in: choose Light, kill and relaunch, it is still Light, and the server holds Light;
  - the cold deep link works, and Back goes to home.
- **T-0063-AC6 (P1-22 AC6).**
  - Choosing dark re-themes the whole app at once, with no restart. Prove it with a widget test over the real `McApp` that checks the brightness of a widget from another feature.
  - The choice survives a restart: local when signed out, and the identity sync when signed in.
  - User switch: A's choice never shows for B. Use held responses for both orders of a switch during a PATCH (epoch pin).
  - Reduce motion disables DS animations, for example the `mc_ds_charts` draw-in.
- **T-0063-AC7 (architecture, codegen and gates).**
  - `mc_arch_check` passes. The barrel exports only the flow, the navigator and arg types. Nothing generated is committed, and output is byte-identical to build_runner's. The cutoff and fixtures checks pass. Globs use `MC_GENERATED_DART`, and `T-0042-AC4_safety.sh` passes after `tool/ide_sync`.
  - Package coverage is ≥ 90 % (and for `mc_appearance`).
  - `test --lockfile_mode=error //...`, lint, `rules_fork.sh check`, `l10n_check` and format (gated directories only) pass.
  - The 50-run flake check passes on new targets.
  - Every evidence row names a test that exists at handoff (protocol).

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Opus). The first worktree was cleaned away during the usage-limit pause, before any edit (the branch was still at the dispatch commit, and no simulator existed). A new worktree was made on the same branch, `.claude/worktrees/mc-T-0063-engineer`.
- 2026-11-27: **Incident, recorded for the TL.** One shell command ran in the Tech Lead's worktree because it had no `cd`. It overwrote the TL worktree's root `BUILD.bazel` with this package's draft. I found it at once (`git status` showed ` M BUILD.bazel`), restored it with `git checkout -- BUILD.bazel` and checked that the TL worktree was clean and on `continue-previous-work`. The file had no uncommitted TL edits: the diff was my content only. From then on every command started with `cd <my worktree> || exit 1`.
- 2026-11-27: Built `mc_appearance` (ADR-0013 drafted), `FileStore.readSync`/`writeSync`, `McApp` following the appearance, the feature, `account_wiring`, the home entry and the link, then the e2e (3/3).
- 2026-11-27: Mutations, first full run: 69 of 74 killed. A02, C03 and D05 survived. A08 timed out: a failing assertion left a held request that teardown then waited on, so the rig now releases held requests first. C15 was broken (the `& false` stopped null promotion). Tests were strengthened for each (an undelivered session change, a double tap on the switch, the gaps measured one by one) and C15 rewritten. Second run: 5 of 5 killed.
- 2026-11-27: **PO 2026-11-27: no feature goldens (ADR to follow; now ADR-0015).** The 10 feature goldens and the `golden_test` target I had added were deleted before handoff. AC4 is now covered by widget tests: German strings, no overflow in the pseudo-locale at 1x and 2x, each of the 4 themes builds both pages in its palette, and the density changes measured sizes. DS goldens are untouched.
- 2026-11-27: `origin/main` merged (T-0062, ADR-0015) with no conflict. Following ADR-0015, `mutations.sh` now holds 16 targeted mutants: the epoch and pin, the merge rule, the 409 re-apply, persistence and the reduce-motion wiring. They were re-run on the merge result.
