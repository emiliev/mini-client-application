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
- 2026-11-27: Handed off at `552c096`.
- 2026-11-27: Review round (TL `/code-review`: 4 important findings, 3 nits). All fixed; see the section below. ADR-0015 was updated meanwhile: no mutation testing in the fix round, and only the important findings block the merge.

## Outcome
**Handed off** for `/code-review` and the TL's merge gates on `fleet/T-0063-settings-appearance` (ADR-0015 as amended: no Verifier pass). Decision: [ADR-0013](../adr/0013-app-wide-appearance.md) (Proposed). Finding: [F-0063](../findings/F-0063-settings-exemplar.md). Evidence: [`documents/evidence/T-0063/engineer/`](../evidence/T-0063/engineer/).

### What was built
- **`utility/mc_appearance`** (new, pure Dart): `AppearancePreferences`, the ports `AppearanceReader` and `AppearanceSettings`, `Appearance` (the device copy saved synchronously, the merge rule, one `PATCH` at a time with `ifVersion` and `authPinned`, the 409 re-apply, the epoch check after every await, and the re-send when the account lost a write), and `AppearanceDIInitializer` (with `followAccount`).
- **`feature/settings/settings_appearance`** (ST):
  - the flow `SettingsAppearanceFlow` with 2 pages: the settings (`settings_appearance`) and "About themes" (`settings_appearance_about`), both tracked as screens;
  - the navigator `SettingsAppearanceNavigator.requestSignIn()`;
  - one bloc, state `loading`, `ready(preferences, sync, signingIn)` or `failure`;
  - UI: `McAppBar` with `McFlowBackButton`, `McSegmented` for the theme and the density, a switch row, the sync status line with Retry, "Sync across devices", and "Reset to defaults" behind `showMcConfirm`;
  - analytics: `settings_changed` with `setting` and `value`;
  - strings in en, de and `en_XA` (29 keys).
- **`app/wiring/account_wiring`**: `SettingsAppearanceRoute` (`/settings/appearance`, `settings_appearance`), `AccountRouteTargets`, `SettingsAppearanceNavigatorImpl` (the shared fixture sheet, "to sync your appearance across devices") and `AccountWiringDIInitializer`.
- **`app/mini_client`**: a Settings entry on home (last, so the other entries keep their places) and the link `miniclient://app/settings/appearance`.

### AC → evidence
Every test below was grepped at the handoff commit.

| AC | Tests and evidence |
|---|---|
| AC1 | BDD "With the defaults, Appearance shows System, Comfortable and Reduce motion off" and "Signed in as the collector, Appearance shows Dark, the account's seed" (1 GET, 0 PATCH). `mc_appearance:sync_test` "u-101 sees Dark, the seed, after one GET and no PATCH" and "u-100 sees the defaults, and only the version seen is kept". `preferences_test`: the defaults and the wire spelling. |
| AC2 | BDD "The account preferences fail: …" (`identity.preferences_error`: local values, "Not synced …", a change still applies, Retry syncs; 6 then 7 GETs, the PATCH body). "A version conflict re-applies the change on the new version, with exactly 2 PATCHes, and ends synced" (`identity.preferences_conflict`, both bodies). "Another device changed another setting …" (`conflictResolved`). `sync_test` groups "failures never block a local change" and "a 409 re-applies only the user change on current" (a second 409 ends offline after exactly 2 PATCHes). |
| AC3 | BDD "The explainer opens in the flow, and Back returns to the settings" (screens in order); "Signed out, Sync across devices waits for sign-in, then the account's values show"; "A choice made signed out goes to the account that signs in, over its value"; "Backing out of sign-in …"; "A double tap on Sync across devices asks to sign in once"; "Reset asks first, and Cancel changes nothing"; "Confirming the reset restores the defaults and syncs them"; "Confirming the reset when everything is already the default does nothing". `account_wiring:routes_test` (the route, home below it, the pushed location, the sheet and its reason, the drift test). `sync_test` group "on sign-in, the account wins unless a local change is not yet synced". |
| AC4 | No feature goldens (PO 2026-11-27, ADR-0015). BDD "In German every string of both pages is German"; "In the pseudo-locale nothing overflows at <scale>x text" (1 and 2). `flow_scope_test`: "the screen tightens under a compact density" (each gap and the switch row); "at 2x text, Compact still tightens the screen, and nothing overflows"; "the settings and the explainer build in <variant>, in its palette, and nothing overflows" (4 variants). `contract_test`: a label for every value in en and de. `app_core:appearance_shell_test` "Compact is the visual density of every theme …". `mc_ds_theme:theme_test` "the density is the platform's unless given …". |
| AC5 | e2e on a fresh `mc-T-0063-engineer-*` simulator (deleted): [summary](../evidence/T-0063/engineer/e2e/e2e-summary.md), 3/3 PASS. `settings_journey_test`: home → Settings → Dark; home and the characters list dark; relaunched, still dark (screenshots 60–64). `settings_signed_in_test`: the sheet, Light, the account holds Light; relaunched, still Light and the account holds Light (65–67). `settings_deeplink_test`: the cold link, then Back to home (68, 68b). The relaunch is a second `main()` in the same process: the runner uninstalls between targets (F-0063 §7 fact 6). Re-run on the merge with `origin/main` (T-0062's runner and bundle id): [3/3 PASS](../evidence/T-0063/engineer/e2e_merged/e2e-summary.md), with no build-failure marker in any log. Also `mini_client:settings_route_test` "miniclient://app/settings/appearance cold opens …". |
| AC6 | `mini_client:settings_route_test` over the real `McApp`: "home's Settings entry opens the appearance, and Dark re-themes the whole app at once: home and the characters list render dark, with no restart"; "signed out, the choice survives a restart …"; "signed in, the choice survives a restart through the account …". `app_core:appearance_shell_test`: re-theme at once with the same router; the first routed frame; Reduce motion turns animations off, and leaves the platform's setting alone; "the charts draw in … under Reduce motion" (`McDonutChart`, `hasRunningAnimations`). `races_test`: a user switch during a PATCH in both orders (before it leaves: the pin; held before or after the server) and during the GET in both orders. BDD race scenarios: "Another user signs in right before the change is sent …" and "… while the change is on its way …". `local_test`: the device copy, a failed save, unreadable data. |
| AC7 | [Gates](../evidence/T-0063/engineer/T-0063-AC7_gates.md); [byte identity 4/4](../evidence/T-0063/engineer/T-0063-AC7_matches_build_runner.md); [cutoff](../evidence/T-0063/engineer/T-0063-AC7_cutoff.md); [not committed](../evidence/T-0063/engineer/T-0063-AC7_generated_not_committed.md); [gen-l10n parity](../evidence/T-0063/engineer/T-0063-AC7_gen_l10n_parity.md); [`test --lockfile_mode=error //...`](../evidence/T-0063/engineer/T-0063-AC7_lockfile_test.txt); [`T-0042-AC4_safety.sh` after `tool/ide_sync`](../evidence/T-0063/engineer/T-0042-AC4_safety.md); [50-run flake check](../evidence/T-0063/engineer/runs_per_test_50.md). `architecture_test` (the barrel, R15, no API in the feature); `l10n_check:workspace_gate_test` "the gate checks the settings_appearance ARB set"; `mc_appearance:no_flutter_test`. |

### Mutations
[`mutations.sh`](../evidence/T-0063/engineer/mutations.sh) (`MC_TASK=T-0063 MC_ROLE=engineer`). It refuses a dirty tree, sets its restore trap before any edit, and counts `Build did NOT complete` as BROKEN and only `FAILED in` as KILLED. It now holds **16 targeted mutants** (ADR-0015), and [all 16 were killed](../evidence/T-0063/engineer/mutations.log) on the merge with `origin/main`:
- the epoch: A01 (an answer for a gone epoch is applied) and A02 (an undelivered session change before a change);
- the merge rule: A05 (another user's pending), A06 (sign-out keeps pending), A07 (the account wins over pending) and A08 (adoption by the account that signs in);
- persistence: A09 (a lost write is never re-sent) and S01 (`writeSync` never renames);
- writes and the 409 policy: A16 (`ifVersion` 0), A17 (a setting changed again while its PATCH was out), A18 (a 409 never retried), A19 (a second 409 retried) and A21 (a conflict always reported as resolved);
- the pin: A26;
- the reduce-motion wiring: B05 and B08.

Before ADR-0015 a full run covered 74 mutants ([run 1](../evidence/T-0063/engineer/mutations_run1.log): 69 killed, 3 survived, 1 timeout, 1 broken). Each gap got a test or a corrected mutant, and [run 2](../evidence/T-0063/engineer/mutations_run2.log) killed those 5.

### Changes outside the feature and `account_wiring` (TL, please confirm)
- `utility/mc_appearance` (new): app-wide state the app shell and the feature both need (ADR-0013).
- `utility/mc_storage`: `FileStore.readSync`/`writeSync`, so the device copy is known before the first frame and no save outlives a test (F-0050 §7). Tests, including 3 that close the package's older coverage gap.
- `utility/mc_ds_theme`: `McTheme.of(variant, visualDensity:)`. Null keeps the platform default, so no existing golden changed.
- `app/wiring/app_core`:
  - `McApp(appearance:)` follows the appearance (theme mode, density, `disableAnimations`);
  - `McAppearanceFlutter`;
  - `AppearanceDIInitializer` in `rootInitializers`;
  - `AppLocations.settingsAppearance`;
  - `appearance_shell_test`, with `mc_ds_charts` as a test-only dependency.
- `utility/mc_test_utils`: the real appearance in `McTestContainer`, with `appearanceFollowsAccount` off by default, so other features' tests send no preferences read. `isolation_test`'s initializer count goes from 11 to 12 (the new entry, not a weakening), plus one new test.
- `app/mini_client`: the Settings entry (last), `settings_route_test`, 3 e2e targets, the new route name in `analytics_screens_test`, BUILD and pubspec.
- `tool/l10n_check` (gate data and a test), `tool/checks/T-0063-AC7_*.sh`, and the root `pubspec.yaml` (2 workspace members). `pubspec.lock` and `MODULE.bazel.lock` are unchanged.

### Test integrity
- No test was skipped or weakened, and there is no `// ignore:`.
- Changed existing tests: `mc_test_utils:isolation_test` (the count, 11 → 12) and `mini_client:analytics_screens_test` (one more route name).
- Deleted: the 10 feature goldens and the `golden_test` target this task had added, before handoff, per PO 2026-11-27 (ADR-0015). They were never on `main`. No DS golden changed.
- `mc_appearance:sync_test` "u-100 sees the defaults …" now expects the saved seen version instead of "nothing is written". That was my own test, changed with the rule before handoff.

### Follow-ups (for `pending-work.md`)
- `app/sandbox/account_sandbox` (P1-22 lists it; out of scope).
- `settings_home` and the `/settings` parent route.
- DS widgets reading the density themselves.
- The boot page follows the saved theme mode since the review round; it does not yet follow the saved density or Reduce motion.

## Review round (TL `/code-review`: 4 important, 3 nits; the one fix round, ADR-0015)
`origin/main` merged first (`1651dd6`, the protocol and journal; no conflict).

| # | Finding | Fix | Pinned by |
|---|---|---|---|
| 1 (important) | The 409 counter was per run, so a later change's first 409 marked the run `offline` | `conflicts` resets after each successful `PATCH`: the retry limit is per change. `tookOtherChanges` stays per run on purpose: the final status describes the values shown, which hold the earlier merge too | `mc_appearance:sync_test` "change A gets a 409 then 200; change B, queued during it, gets its own 409 then 200: the run ends conflictResolved, never offline" (held requests, 4 PATCHes, B's first body checked); mutant R1 |
| 2 (important) | A change that joined a finished run stayed pending: `_run` was cleared a microtask late, after the final snapshot's listeners | The run clears `_run`/`_runEpoch` in its own `finally`, before its future completes (a run id guards a run that ended without awaiting) | `sync_test` "a change made by a listener of the synced snapshot is sent and ends synced"; mutant R2 |
| 3 (important) | A throwing `requestSignIn()` left "Waiting for you to sign in." and the CTA disabled | The bloc catches it, reports it (`addError` → monitoring) and shows the state again | BDD "Signing in fails: the error is reported, and Sync across devices can be tapped again (review round)" (new step `signing in fails`); mutant R3 |
| 4 (important) | A failed device save replaced the screen with an error view | `failure` keeps `sync` and `signingIn`; the page renders every control with a "Not saved" banner on top, whose Retry saves again | BDD "The device cannot save: the controls stay, every change still applies, a banner says so, and Retry tries again" (Dark, then Light, then Reduce motion, all applied; the banner stays) |
| 5 (nit, done: a few lines) | A corrupt saved file was never replaced while the values equalled the defaults | After a restore failure the first save writes anyway (`_forceSave`) | `local_test` "a corrupt saved copy is replaced on the first save, even when the values equal the defaults" |
| 6 (nit, done: one line) | Reduce motion still cross-faded the theme | `MaterialApp.router(themeAnimationDuration: Duration.zero)` while Reduce motion is on | `app_core:appearance_shell_test` "with Reduce motion on a new theme applies in the next frame" and its control "… off … cross-fades" |
| 7 (nit, done: small) | A saved Dark flashed light on the boot page | Small, so done: `savedAppearance(FileStore)` (new, synchronous) seeds `MiniClientApp`'s `McThemeModeController` before boot (`MiniClientApp(storageDirectory:)`); `McApp` drives it from the live appearance after boot | `mini_client:settings_route_test` "the boot page of the next launch is already in the saved Dark: no light flash while booting (review round)" and "with nothing saved the boot page follows the platform"; `local_test` "savedAppearance reads the saved preferences, and null when none or unreadable" |

**Mutants:**
- ADR-0015 as updated (TL, this round): there is no mutation testing in the fix round, and `mutations.sh` stays as handed off, with 16 mutants.
- One run had already finished when that update arrived. It had A21 and B08 swapped for R1 to R3 (one for each of items 1 to 3), and it killed 17 of 17, R1 to R3 included. So the new tests bite.
- That run is not kept as evidence, and the script is back to its handed-off version.

**Results**, on the merge with `origin/main` plus this round:
- [Gates](../evidence/T-0063/engineer/T-0063-AC7_gates.md): PASS. 214/214 tests, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures, relative paths, byte identity, cutoff, not committed, gen-l10n parity.
- Coverage: settings_appearance 99.3 %, account_wiring 100 %, app_core 97.2 %, mc_appearance 99.1 %, mc_storage 100 %, mc_ds_theme 92.7 %.
- [50-run flake check](../evidence/T-0063/engineer/runs_per_test_50_review.md): 11 changed targets, 50 runs each, 0 failures.
- e2e: the 3 settings targets on a fresh `mc-T-0063-engineer-*` simulator (deleted afterwards), [3/3 PASS](../evidence/T-0063/engineer/e2e_review/e2e-summary.md).

**Test integrity:**
- No test was deleted, skipped or weakened.
- The scenario "The device cannot save: …" was rewritten, not weakened: it now asserts more (the controls stay, two more changes apply, the banner shows) and drops only the full-screen error the review asked to remove.
- Additions: the new step `the app was asked to sign in {n} times` (the plural form); `mini_client`'s BUILD and pubspec gain `mc_appearance` and `mc_storage` as runtime dependencies (the boot seed).
