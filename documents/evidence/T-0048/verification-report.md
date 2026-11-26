# Verification report — T-0048: `library_reading_list_editor` exemplar (FW), P1-20

- **Verifier:** crew: Verifier, Opus tier (fresh agent, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0048-reading-list-editor` @ `27d9d39` (detached, merge base `origin/main` `1d9bde1`)
- **Simulator:** `mc-T-0048-verifier-59104`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it (`SIMULATOR_DELETED_AT=1795736749`; `xcrun simctl list devices | grep -c mc-T-0048-verifier` → `0`). I didn't touch any shared simulator.
- **Bazel:** `/tmp/mc-ob-T-0048-verifier`, plus `/tmp/mc-ob-T-0048-verifier-e2e` for a second, unmutated scratch worktree that I used for probes and the e2e project. Both were shut down at the end.
- **Verdict:** **PASS.** Every AC passes on its tests and on my probes. Two Medium defects and some Minor test gaps are listed below. The two Medium ones matter before the FW bricks copy this package: D1 corrects the risk assessment of the known P-083, and D2 is a stuck guard in the home caller.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0048-verifier tool/checks/T-0048-AC8_gates.sh --role verifier` | **PASS**, every row: test //..., lint, mc_arch_check, rules_fork.sh check, dart format, l10n_check, fixtures check, relative API paths, the four AC7 checks, coverage |
| Tests, uncached | `test --nocache_test_results --noremote_accept_cached` over the feature, `//app/...`, mc_forms, mc_api_errors, mc_fixtures_library, mc_ds_forms, mc_test_steps, l10n_check | **36/36 targets PASS**. They really ran: bdd_test 8.2 s, flow_scope 2.5 s, golden 2.7 s. The gate's `test //...` shows 137/137 |
| Coverage | `bazel coverage` over the 7 packages, then **my own parser**. It takes the union of per-target LCOV, keeps hand-written `lib/` only, and also lists `lib/` files that no LCOV mentions | library_reading_list_editor **723/736 = 98.2 %**, library_wiring 37/37, app_core 354/368 = 96.2 %, publishing_wiring 47/47, **mc_forms 286/286 = 100 %**, **mc_api_errors 60/60 = 100 %**, mc_fixtures_library 203/206 = 98.5 %. The files that no LCOV mentions are barrels, abstract interfaces, a retrofit redirecting factory and freezed-only state files, none of which has an executable line. My numbers match the engineer's exactly |
| AC7 byte identity | `T-0048-AC7_matches_build_runner.sh`, re-run on its own in the unmutated worktree (it runs build_runner through the reference overlays) | **12 of 12 EQUAL**, none missing, none extra |
| AC7 cutoff, not committed, gen-l10n parity | inside the gate run | PASS |
| T-0042-AC4 | `tool/ide_sync --env dev` (`IDE_SYNC copied=46`), then `T-0042-AC4_safety.sh`, then `tool/ide_sync --clean` (`cleaned=82`, `git status` clean) | **PASS** ([t0042_safety.md](verifier/t0042_safety.md)): the synced tree ran 0 actions and 0 of 137 tests, 47,178 outputs had the same bytes, and all 4 negative controls fired |
| L4 E2E | `tool/e2e/prepare_pub_project.sh --app app/mini_client`, then `tool/e2e_ios.sh --task T-0048 --role verifier` with 4 targets | `reading_list_journey` PASS 64 s, `reading_list_deeplink` PASS 30 s, **my `verifier_probe_test`** PASS 44 s, `comics_journey` PASS 35 s (the moved sheet keys) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0048-AC1 | 3 steps, POST with exactly those values in the chosen order, completes with the id | BDD create, especially "Three steps create a list…". contract_test. Goldens | **Yes.** The step `the backend received {route} with the body` decodes the wire body and compares it with `expect(actual, expected)` on the whole map, so an extra or missing key fails. I checked that the `comicIds` order `[500060, 500062, 500061]` is the reordered one. It also checks the bearer, `201`, the stored list read directly from the backend (not through the app), and exactly one `DataChanged`. Rules: I counted the example strings. 61 `a` is rejected, 60 trimmed is accepted, 281 `d` is rejected. **60 flags (120 runes) pass on both sides** (BDD) and 61 flags fail in the backend (`validation_test`). Killed: AC1-b, AC1-d, V16, V25 | **PASS** |
| T-0048-AC2 | `server_error` shows an inline error with Retry (1 then 2 POSTs, same body). A 400 goes back to step 1 with the error under the name | BDD create and edit. `mc_forms` and `mc_api_errors` solitary tests. contract_test | **Yes.** `duplicate_name` (`' weekend reads '` against "Weekend Reads") takes the wizard back to step 1, shows the error under Name, disables Next and sends no announcement. Re-entering the same value keeps the error. A changed value clears it. Then the second POST succeeds. Killed: AC2-c, AC2-i, V09, V11–V15. Survived: V08 and V10, kit test gaps (D4) | **PASS** |
| T-0048-AC3 | Edit pre-fills all steps, PUTs only the changed parts, a no-change save sends nothing and completes with the same id, another user's list is not found | BDD edit, flow_scope "a different list", routes_test, reading_list_route_test | **Yes.** Pre-fill covers name, description, visibility (semantics `isSelected`), the chips and the order. Name only gives 1 `PUT` and 0 `/items`. Order only gives the reverse. Both changed give both, with the request order asserted. No change gives 0 PUTs, the result `l-1` and 0 announcements. **`l-3` (empty) renamed** gives 1 `PUT l-3` and 0 items. `l-4` (u-101's) and `l-999` show not found. Killed: AC3-a, AC3-g | **PASS** |
| T-0048-AC4 | German, and `en_XA` at 1× and 2× with no overflow | BDD l10n. `l10n_check` gate | **Yes** for the wizard steps, validation, save error, signing in and the ended session. `nothing overflows` calls `takeException()`. Gap (Minor, D5): `en_XA` isn't run on the not-found and load-failed states, and the German duplicate-name message has no scenario. The key exists (the l10n gate checks it) | **PASS** |
| T-0048-AC5 | e2e: home → New → invalid step 1 → fix → steps → submit → "List created: l-5"; the deep link | e2e on my simulator, plus my probe target | **Yes.** I looked at every screenshot (see below). **My probe on the device:** Back on step 1 returns home with no result. **The iOS back swipe on step 3 goes to step 2** with both picks kept (v01). **The swipe on step 2 goes to step 1** with the name and Public kept (v02). The app-bar back on step 3 and the step bar's Back on step 2 each go one step. Create still gives `l-5`. A link to edit `l-5` (a `go`, nothing below it) saves and **goes home** (v03) | **PASS** |
| T-0048-AC6 | Blocked Next, the result reaches the caller, double submit, session change during submit, back keeps values | BDD races, create and l10n. flow_scope_test. app_core flow_results_test. library_wiring routes_test. mini_client reading_list_route_test | **Yes**, for every race the brief lists, both held and released: double Create and double Save (1 write each), a user switch during the save (POST with reader's token, collector still has 1 list, no result, 1 announcement), between two writes (0 `/items`, l-1 unchanged), sign-out during the save and before Finish, the session change during the load, leaving during a held load or a held sign-in (`takeException` is null, `monitoring.errors` empty, no request), the editor closed mid-save (announces, no `/items`), an older search answering late, going back during a held search, and back during a save (swipe refused, buttons off). All 14 of the engineer's AC6 mutations I sampled were killed. **Probe (D1):** a user switch one event-loop turn after the bloc's check sends the POST **with the new user's token**. That is the known P-083 gap, but it is wider than P-083 says | **PASS** (D1 is the pre-existing P-083) |
| T-0048-AC7 | arch check, barrel, codegen, fixtures, `MC_GENERATED_DART`, T-0042-AC4 | architecture_test, flow_scope_test, gates, my byte-identity re-run | **Yes.** The barrel `show`s exactly `ReadingListId`, `ReadingListEditorFlow` and `ReadingListEditorNavigator` (I read it). `mc_arch_check` OK. 12/12 EQUAL to build_runner. Every `lib/**` glob in the feature, library_wiring, app_core, publishing_wiring and mc_fixtures_library excludes `MC_GENERATED_DART`. T-0042-AC4 PASS | **PASS** |
| T-0048-AC8 | coverage ≥ 90 %, the gates, traceability | gates, my own coverage parser | **Yes** (above). Every BDD scenario has a `@T-0048-ACn` tag, and every new test name in `app_core`, `library_wiring`, `mini_client`, `mc_forms`, `mc_api_errors` and `mc_fixtures_library` contains its AC id | **PASS** |

## The flow-result pattern
- **Verified:**
  - The caller awaits `AppFlows.createReadingList` and gets the id: tested in app_core, library_wiring and the real app.
  - Back gives null.
  - A deep-linked editor goes home: tested, and seen on the device (v03).
  - A second completion is ignored, and a late one does nothing.
- **My probes in `flow_results_test`, all PASS on unmutated code** ([source](verifier/probe_flow_results_overlays.dart.txt)):
  - A result under a **modal bottom sheet** is kept and delivered once the sheet closes.
  - Under a **dialog with a sheet on top of it**, the result waits for both to close (after the sheet closes, `done` is still false and the dialog is still shown).
  - Under **another pushed page**, it is delivered when that page is popped.
  - A pushed result route **replaced by `go` never completes its caller** (go_router 17.5 completes `push<T>` only on pop, `delegate.dart:184`). This is the root cause of D2.
- **Home ignores a double tap:** AC5-c and V07 were killed. But D2.
- **Is it clean enough for the bricks to copy?** Yes, mostly. The three layers are each simple. The overlay handling is right, and it doesn't leak go_router internals into features. What I would change:
  1. Document in F-0048 fact 1 and `flow_results.dart` that **the future may never complete**, when the route is replaced by `go` (a link). Callers must not hold state on it. Either make `FlowResultRoute` complete the caller with null on dispose, or give callers a route-aware guard (D2).
  2. Give `FlowResultRoute` an optional fallback location instead of the hard-coded `AppLocations.home`. Not every linkable result flow is a home flow.
  3. `AppFlows` in `app_core` will gain an entry for each of about 100 features. That is a single file every FW brick edits (merge churn for parallel crew). Consider putting each group's typed entries in its wiring barrel, or generating them.

## Kit changes
- **`ApiClientError` carries `code` and `parameter`.** It reads them from a map body or a JSON text body. A body of any other shape gives null for both. Tested, and V11 and V12 were killed. Coverage is 100 %.
- **`reject()` behaves the same on `FormController` and `WizardController`.** It sets the error and touches the field. A changed value clears the error, and the same value keeps it. A failing rule wins over the server error. A failed submit goes back to idle (V09 killed). `WizardController.reject` moves to the field's step, back or forward. Both are ignored while a submit runs.
- **Gaps:**
  - Wizard: the "ignored while completing" guard (V08) is only checked on the field's own step, where `FormController` already ignores the call.
  - Form: "reset forgets the server errors" passes without `_rejected.clear()` (V10), because the test changes the value afterwards (D4).
- **`mc_fixtures_library`:**
  - It counts graphemes, for both the name and the description (V15 killed).
  - It has `duplicate_name`: case-insensitive after trimming (V14), a renamed list may keep its own name (V13), another user's names don't count, and it comes after a malformed name. CONTRACT.md is updated.
  - T-0047's tests are unchanged: the diff only adds to `validation_test.dart`. All 4 targets PASS uncached.

## Mutations
[log](verifier/mutations.log), [script](verifier/mutations.sh.txt) (the engineer's harness, copied, plus my own mutations V01–V25). Every mutation was restored, and `git status` was clean after the run. **36 of 45 were killed by a failing test, with no compile errors.**
- **The engineer's mutations: 20 of 20 sampled were killed.** AC1-b, AC1-d, AC2-c, AC2-i, AC3-a, AC3-g, AC5-c, AC6-e, -f, -h, -i, -j, -k, -l, -m, -o, -t, -u, -v, -w.
- **Mine: 16 of 25 were killed.** V03–V07, V09, V11–V18, V24, V25.
- **Mine that survived (all test gaps, the code is correct):**
  - V01 and V02: the pre-write epoch checks before the POST and before the first PUT. The handler runs in the same turn as the event, so a real event can't reach these.
  - V08 and V10: the kit gaps above.
  - V19: the sign-in gate trusts a `true` from the navigator without a session.
  - V20: the guard against a double Retry of the load.
  - V21: the `description` parameter mapping, which a valid form can no longer reach.
  - V22: the `too_many_comics` message mapping.
  - V23: the session listener's guard against adding after close.

## Test-integrity audit
- **Removed (TL decision 2), justified:**
  - BDD "A description the backend refuses…": the backend now counts graphemes as the form does, so a valid description can't be refused.
  - The contract tests of the removed side channel: that behaviour now lives in `mc_api_errors`, whose tests cover it.

  Neither removal is a weakening.
- **Changed, justified:**
  - BDD "A name the backend refuses…" uses `duplicate_name` instead of 31 flags. It is stricter than before: it also checks that 0 changes are announced and that the same value keeps the error.
  - BDD "Another user signing in during the save" now expects `{1}` announcement, and flow_scope "closed while its save is held" expects one `readingLists` announcement. Both follow TL item 6 (a write is announced) and both are equality checks, not looser ones.
  - The comics e2e journey only follows the key rename.
- **Elsewhere:** every other test file in the diff only adds lines (`git diff --stat`), including T-0047's `validation_test`. publishing_wiring's `routes_test` is unchanged.
- **Lint suppressions added:** none. `git diff origin/main...HEAD | grep '^+.*// ignore'` matches only the task file's prose. No `skip:`.
- **Golden files:** 7 new ones, no existing golden changed. I looked at `step3_save_failed` (inline error with Retry, order rows, "Save changes") and `session_ended` (message and Close, no back).

## Visual acceptance
I looked at all 21 screenshots: 30–38 (reading list), 10–17 (comics journey) and v01–v03 (my probes). Four are kept.

| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Blocked step 1 (AC5, AC6) | [32_step1_blocked.png](verifier/32_step1_blocked.png) | "New reading list". The Name field has a red border and "Give your list a name." under it. "Step 1 of 3". Next is disabled (grey) | yes |
| Order and review (AC1) | [35_step3_review.png](verifier/35_step3_review.png) | "Amber reads", "Where Amber begins.", "Public". Reading order: #1, #3, #2 after the move, with arrows (row 1's up and row 3's down are disabled) and drag handles. "Create list" | yes |
| Home shows the result (AC5, AC6) | [36_home_list_created.png](verifier/36_home_list_created.png) | "List created: l-5" and "Edit list l-5" below "New reading list" | yes |
| Back swipe on step 3 (AC5, AC6) | [v01_swipe_back_to_step2.png](verifier/v01_swipe_back_to_step2.png) | "Pick comics", "Step 2 of 3", "2 comics picked", both chips and both rows checked | yes |

Not kept:
- 30: home with "New reading list".
- 31: the sheet, "Sign in as Rhea Reader … to save your reading lists.", over "Sign in to continue".
- 33: step 1 filled in, with Public selected.
- 34: 3 picked chips and checked rows.
- 37: the linked editor at step 1, with no back button (P-087, known).
- 38: "Edit reading list" filled in with Spider-Verse Starter.
- v02: step 1 after the swipe, "Amber reads" and Public kept.
- v03: home after the linked save.
- 10–17: the comics journey, with the shared sheet.

## Issues found
1. **D1 (Medium; pre-existing kit gap P-083, which says the risk is smaller than it is).**
   - **What happens:** a user switch in the window between the bloc's epoch check and the auth interceptor writes a list **into the new user's account**.
   - **Why:** Dio runs every request interceptor in `Future(() …)` (`dio-5.11.1/lib/src/dio_mixin.dart:439`), which is a timer, so a new event-loop turn. The auth interceptor is the third one. It reads the token **at send time** and has no epoch guard for a first send (`utility/mc_api_auth/lib/src/auth_interceptor.dart:56-71`). P-083 calls the gap "only a few microtasks". It is in fact **at least one event-loop turn per interceptor**, so any event (for example a sign-in response from elsewhere) can land in it.
   - **Repro** ([probe](verifier/probe_user_switch_window.dart.txt), unmutated code):
     1. Reach step 3.
     2. `await tester.tap(find.text('Create list'))`.
     3. Call `diContainer<Session>().signIn(u-101 …)`, then `mcSettle`.
     4. The requests are `POST /v1/me/lists Bearer mc-access-u-101-1`. The editor doesn't hand the list out, but collector now has it.
   - **The same gap applies to** `updateDetails` and `replaceItems` (`reading_list_editor_bloc.dart:338-353`) and to T-0041's favourite.
   - **Fix (kit):** as P-083 proposes, the caller pins the epoch in `options.extra`, and the interceptor rejects a first send whose epoch is no longer current. The repository or `apiCall` passes the epoch the bloc checked.
   - **Recommendation:** do this before the FW bricks, since every FW write copies this bloc.
2. **D2 (Medium).** Home's New and Edit go dead after a link replaces an open editor.
   - **Where:** `app/mini_client/lib/src/pages/placeholder_pages.dart:48-61`. `_awaiting` is reset only when the push future completes. go_router never completes a push that `go` replaced (probe above), and the home page's state survives a `go('/')`.
   - **Repro** ([probe](verifier/probe_home_after_link.dart.txt), fails on unmutated code):
     1. Boot, tap New reading list, sign in. Step 1 is shown.
     2. Push the link `miniclient://app/`. Home is shown.
     3. Tap New reading list. Nothing opens: `Found 0 widgets with text "Step 1 of 3"`.

     Any link to `/` (or to a child of home) while an editor is open does this, until the app restarts.
   - **Fix:** make the guard route-aware. For example, ignore the tap only while `ModalRoute.of(context)?.isCurrent == false`. Or make `FlowResultRoute` guarantee that its caller completes.
   - Record the "may never complete" rule in F-0048 for the bricks.
3. **D3 (Minor, test gap).** These guards are correct but no test pins them, so deleting one leaves the suite green:
   - the pre-write epoch checks (V01, V02, at `reading_list_editor_bloc.dart:327, 338`);
   - the sign-in gate's `!_session.isSignedIn` (V19, `:196`);
   - the load's `_loading` guard (V20, `:212`);
   - the session listener's `isClosed` guard (V23, `:84`);
   - the `description` and `too_many_comics` mappings (V21, V22, `reading_list_form.dart:17-18, 49`; also the two uncovered lines).
4. **D4 (Minor, kit test gaps).**
   - `form_controller_test.dart:393` "reset forgets the server errors" is vacuous: it passes without `_rejected.clear()` (V10), because `_fill` changes the value afterwards.
   - `wizard_controller_test.dart:417` only checks the completing guard on the field's own step, so removing `_state.isCompleting` from `WizardController.reject` (V08) survives.
5. **D5 (Minor).** The Outcome claims `en_XA` at 1× and 2× "through every step and every state outside the wizard". Not found and the failed load aren't run under `en_XA`, and the German duplicate-name message has no scenario (`reading_list_editor_l10n.feature`).

## Notes for the Tech Lead
- None of D1–D5 makes an AC fail on the tests as written. D1 is P-083: please update its text with the event-loop finding and raise it to "before the FW bricks". D2 is the home caller, but its lesson, that a result future may never complete, belongs in the pattern the bricks copy.
- Evidence: [gates.md](verifier/gates.md), [byte_identity.md](verifier/byte_identity.md), [t0042_safety.md](verifier/t0042_safety.md), [e2e-summary.md](verifier/e2e-summary.md) (it lists every screenshot, but only the 4 above are kept), [the probe e2e target](verifier/verifier_probe_test.dart.txt), [the overlay probes](verifier/probe_flow_results_overlays.dart.txt).
- I did the probes in a second, detached worktree on `27d9d39` (inside my scratch folder), never in this tree, and removed it afterwards. Only the mutation run touched this tree, and it restored every file.
