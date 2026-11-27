# Verification report — T-0049: Cold deep links get a back stack; home's flow buttons survive a link

- **Verifier:** crew: Verifier, Opus tier (a fresh agent; I did not write this code)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0049-deep-link-back-stack` @ `bbb903b` (merge base `c6ac300` = `origin/main`)
- **Simulator:** `mc-T-0049-verifier-95721`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it (`SIMULATOR_DELETED_AT=1795763098`). `xcrun simctl list devices | grep -c mc-T-0049-verifier` gives `0`. I didn't touch any shared simulator.
- **Bazel:** `/tmp/mc-ob-T-0049-verifier` for the gates, probes and mutations. `/tmp/mc-ob-T-0049-verifier-e2e` was used for `prepare_pub_project.sh`, run from a second scratch worktree that has since been removed. Both servers are shut down.
- **Verdict:** **PASS.** Every AC passes on its tests, on my own probes and on the simulator.
  - I found five Minor defects. None breaks an AC as written.
  - D1 deserves attention before the `/me/**` auth guard lands (P1-16 AC4). With that guard, a caller can again wait forever, and the debug assert can fire on a route that is written correctly.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All AC4 gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0049-verifier tool/checks/T-0049-AC4_gates.sh --role verifier` ([gates.md](verifier/gates.md)) | **PASS** on every row: `test //...` (with `//app/...` uncached), lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, fixtures check, relative API paths, coverage. 146/146 tests. The output base was fresh, so everything was built and run from scratch |
| Coverage, my own parser | [coverage_parser.py.txt](verifier/coverage_parser.py.txt). It takes the union of each package's **own** test targets' LCOV, counts hand-written `lib/` code only, and lists `lib/` files that no LCOV mentions | mini_client 104/109 = **95.4 %**, app_core 427/444 = **96.2 %**, library / publishing / universe / discovery wirings **100 %** (39, 47, 39, 22 lines). In `flow_results.dart`, 73/75 lines are covered. The two misses are the token-count branches for more than one call (lines 114 and 230). In `route_nesting.dart`, 26/27 are covered. The miss is a non-home app route passing through (line 33). The only files that no LCOV mentions are barrels, `main.dart` and the abstract `route_targets.dart` files. My numbers match the engineer's |
| L4 E2E | `prepare_pub_project.sh --app app/mini_client`, then `tool/e2e_ios.sh --task T-0049 --role verifier` with **15 targets**: the full suite of 10, plus 5 probe targets of mine ([summary](verifier/e2e-summary.md)) | **15/15 PASS.** I looked at all 52 screenshots |
| AppLocations / URLs | `git diff origin/main bbb903b -- app/wiring/app_core/lib/src/locations/app_locations.dart` | **empty.** No `@TypedGoRoute` path changed; only doc comments and `extra: state.extra` were added. The drift test of every wiring (`routes_test`) passed in the gate run |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0049-AC1 | A cold link to each of the five targets shows a back button, and Back walks the nested path to home | `deep_link_back_stack_test`: `T-0049-AC1 a cold start from <link> …` (5 tests). `route_nesting_test` (4). e2e: `characters_deeplink`, `character_details_deeplink`, `comic_deeplink`, `search_deeplink`, `reading_list_deeplink` | **Yes.** `walkHome` taps Back exactly once, and for `/characters/<id>` it first taps once to the list and checks that home isn't shown yet. Then it requires home **and no `BackButton`**, so an extra page anywhere fails. **My probes (widget):**<br>• `/me/lists/l-1/edit`: stack `[/, me/lists/:id/edit]`, one Back to home.<br>• `/search?q=spi#top`: field shows `spi`, one Back to home.<br>• `/creators/1`: nested too, `[/, creators/:id]`.<br>**My probes (device):** cold `/me/lists/l-1/edit` and `/search?q=spi#top` each show one back button, and one Back leads to home with no back button on it.<br>`/comics/abc` and `/nope` show the not-found page **alone, with no back button and no way home** (D4; outside the AC's five links, and not new). Killed: N2, N4, N5, N6, N8, V05, V06, V07 | **PASS** |
| T-0049-AC2 | A link into the running app gives the stack `[home, target]`; one Back returns to home; older link tests stay green | `deep_link_back_stack_test`: `T-0049-AC2 a link to the running app (<link>) …` (5). F-0049 fact 2 documents the go semantics | **Yes, with one gap (D5).** **Links as push** (my per-navigation variant of P1, which doesn't share state between tests) turn red: 4 of the 5 AC2 tests, the D2 test, 8 of my probes, and `app_test` T-0021-AC4. The `/characters/<id>` AC2 test stays green because the test opens the characters list first, so push and go give the same stack. **My probes:** a link from the characters **preview** gives `[/, comics/:id]`; from reading-list **step 2**, `[/, search]`; from inside the open **sign-in sheet**, `[/, comics/:id]` with the sheet gone. Each then takes one Back to home with nothing below it, and New opens the editor again. The same three run on the device in `v0_running_probes` and pass. `links_after_flow_test` (T-0033/T-0035), `app_test` (T-0021) and the e2e `characters_link_after_flow` are green | **PASS** |
| T-0049-AC3 | A link replaces the open editor and New opens it again (the caller got null). `FlowResultRoute` disposed without a result (pop, replace, go) completes once with null | `deep_link_back_stack_test` `T-0049-AC3 a link to home replaces an open editor …`. `flow_results_test` groups `T-0049-AC3` (9) and the codec group (2). e2e `reading_list_deeplink` (37c) | **Yes.** The future completes with null when the route is replaced by a go, replaced by a go elsewhere, or popped by Back. It gives the id on finish, and the result once when the user finishes and then leaves. **D2 repro** (the T-0048 Verifier's probe, re-run as is): passes. **Edit** also works again after a link replaced the editor, and then saves `l-5`.<br>**My probes:**<br>• system Back (`handlePopRoute`) gives null;<br>• a result plus a `go` in the same synchronous span gives the result;<br>• an encoded id `a b/é` causes no false assert and returns the id;<br>• two `AppFlows` calls to the same location, then a go, give `[null, null]` with no error;<br>• a forgotten extra under `nestUnderHome` still asserts;<br>• a link to the same location doesn't trip the assert.<br>**Codec:** I captured go_router's log in a widget test (`debugLogDiagnostics: true`, through `testDeveloperLog`). With `FlowExtraCodec` there were 0 "complex data type" warnings; the control without a codec logged 2. The restored route state holds no `FlowCall`. The app's router has no `debugLogDiagnostics`, so go_router logs nothing on the device either way. **I did not capture device logs.** Killed: R1–R8, V01–V04, V09–V12. **Survived: V08** (D1) | **PASS** |
| T-0049-AC4 | Drift tests, gates, full e2e, `MC_GENERATED_DART` globs | Gate script, plus my coverage parser and e2e | **Yes.** See the gates table. The new BUILD target adds no glob, and app_core's `lib/**` glob already excludes `MC_GENERATED_DART` | **PASS** |

## Mutations
[log](verifier/mutations.log), [script](verifier/mutations.sh.txt): the engineer's harness, copied, with my V01–V12 added. Every file was restored, and `git status` was clean after each run.
- **The engineer's mutations: 14 of 17 sampled, all killed.** N2, N4, N5, N6, R1–R8, P1, N8.
- **Mine: 11 of 12 killed.**
  - V01: `AppFlows` returns the bare push future, as before T-0049.
  - V02: no `FlowCall` extra.
  - V03: the route never takes its token.
  - V04: the first-route branch pops.
  - V05 to V07: nesting order, a dropped name, a relative route accepted.
  - V09: the route ignores its extra.
  - V10: dispose completes with a non-null value.
  - V11: the edit route forgets its extra.
  - V12: the debug check is skipped under a GoRouter.
- **Survived: V08**, which stops chaining the push future into the call. No test pushes an `AppFlows` location that ends on something other than a `FlowResultRoute`.
- **P1 (links as push):** I ran it a second time and collected every result, not just the first failure. The engineer's P1 keeps a set across tests, which hides some failures in later tests (`/comics/501500` is already in the set). My variant decides per navigation, with a one-shot flag; its results are in the AC2 row.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none.
  - `backToHome` (up to 3 Backs until home) became `walkHome`. It taps an exact number of times, checks the list in between for `/characters/<id>`, and requires no back button on home. It is strictly stronger, and every old assertion is still there.
  - The e2e edits only add checks. The only removed `testWidgets` line is the renamed `T-0033-AC4 T-0049-AC1 …` test in `characters_deeplink_test.dart`, with the same body plus the back checks.
  - `search_deeplink` inserts Back plus a re-link before the old `amber` link; the old assertions are unchanged.
- **Lint suppressions added:** none (`git diff origin/main...bbb903b` has no added `// ignore` or `ignore_for_file` line).
- **Golden files updated:** none.
- Every AC has tests named `T-0049-ACn`. AC4 is the gate script (`PASS T-0049-AC4-gates`).

## Visual acceptance
I looked at all 52 screenshots, the engineer's checkpoints and my probes. Four are kept here.

| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Cold `/characters/100366` | [55_deep_link_character_details.png](verifier/55_deep_link_character_details.png) | "Character 100366" app bar with a back chevron; "Character details 100366" placeholder | Yes (AC1: a back button) |
| Back once | [55b_back_from_details_is_list.png](verifier/55b_back_from_details_is_list.png) | "Characters" grid (Amber Alchemist, Artisan, Bard, Beacon), back chevron still shown | Yes (details sit under the list) |
| Back again | [55c_back_from_list_is_home.png](verifier/55c_back_from_list_is_home.png) | "Mini Client" home with no back chevron; Characters, New reading list, Search, Open placeholder 7 | Yes (home is the bottom) |
| Cold `/comics/abc` (probe) | [v3_cold_bad_comic.png](verifier/v3_cold_bad_comic.png) | "Not found" app bar, **no back chevron**, "Nothing lives at /comics/abc" | Outside the AC; shows D4 |

The others were not kept:
- the cold `/characters`, `/comics/501500`, `/search?q=spi` (field `spi`, grouped results) and `/me/lists/new` (step 1) screens each show a back chevron, and each `*b` shot is home without one;
- in `37c`, the editor opens again after a link replaced it;
- `v1_sign_in_sheet_before_link` shows the sheet over the editor, and in `v1b` the comic replaces it;
- `v1_cold_edit` shows "Spider-Verse Starter" filled in with a back chevron.

## Issues found
1. **D1 (Minor now; Medium once the `/me/**` guard lands).** A redirected `AppFlows` push that a `go` then replaces leaves the caller waiting forever, and the debug assert fires on a correctly written route.
   - **Where:** `app/wiring/app_core/lib/src/router/flow_results.dart:236` and `:117`.
     - When the pushed location doesn't build a `FlowResultRoute`, only the push future can complete the call (line 236), and go_router never completes it after a `go`.
     - The debug token is keyed by location. A later `go` to that location builds the route without a call, so it throws "built without its FlowCall".
   - **Repro** (probe `a redirected AppFlows push …` in [verifier_flow_probe_test.dart.txt](verifier/verifier_flow_probe_test.dart.txt)):
     1. Set up a redirect from `/me/**` to `/signin` while signed out (plan 01 §4.2's guard has this shape).
     2. Call `AppFlows.createReadingList`. The sign-in page shows.
     3. Sign in, then `go('/me/lists/new')`, as a guard's `from=` does.
     4. Result: a `FlutterError` "…built without its FlowCall…", and the caller has still not completed after `go('/')`.
   - Mutation V08 surviving is the same gap.
   - **Suggestion:** complete the call when its imperative match leaves `routerDelegate.currentConfiguration`, for example from a delegate listener in `_open`. Tie the debug token to the call instead of the location.
2. **D2 (Minor, latent).** `FlowExtraCodec` passes every other extra through unchanged.
   - **Where:** `flow_results.dart:198`. go_router sends the encoded state to the engine (`SystemNavigator.routeInformationUpdated`).
   - **Effect:** a non-JSON extra now throws `JsonUnsupportedObjectError`. Without the codec, go_router dropped it to null with a warning (control probe).
   - **Why it matters:** plan 01 §4.4 reserves `$extra` for picker arguments, so the first picker that passes a value type will trip this.
   - **Repro:** probe `VPROBE-EXPECT? codec passes a non-JSON extra …`. It fails by design and shows the error.
   - **Suggestion:** pass through only JSON-encodable values and encode the rest as null, or document that every extra must be JSON-encodable.
3. **D3 (Minor).** A result that is waiting under an overlay is lost if a `go` replaces the route.
   - **Where:** `flow_results.dart:144`. `dispose` completes with null and ignores `_pending`.
   - **Repro:** probe `a result pending under a dialog, then a go`. The flow completes with `l-7` under a dialog, then `go('/')` runs, and the caller gets `null`.
   - **Suggestion:** `_call?.complete(_pending?.value)`.
4. **D4 (Minor, existed before this task, outside AC1's links).** A link to an unknown path, or to `/comics/abc`, shows the not-found page as the only route, with no back button and no way home. This is the same "stuck" state that P-087 fixed for entity links.
   - **Where:** `app/mini_client/lib/src/router/app_router.dart:43`, `app/mini_client/lib/src/pages/placeholder_pages.dart:171`.
   - **Repro:** cold start with `/nope` or `/comics/abc` (on the device in `v3`/`v4`, and in widget probes: stack `[null]`, `canPop=false`).
   - **Suggestion:** add a "Go home" action to `NotFoundPage` (pending-work).
5. **D5 (Minor test gap).** The AC2 test for `/characters/<id>` cannot tell a go from a push.
   - **Where:** `app/mini_client/test/deep_link_back_stack_test.dart:156`. The test opens the characters list first, which is also the link's parent.
   - **Suggestion:** open the search first for that link.

## Notes for the Tech Lead
- go_router has no way to complete the future of a push that a `go` replaced (F-0049 fact 3, confirmed). The `FlowCall` design fixes this for every path that reaches a `FlowResultRoute`.
- F-0049 states "a result future always completes". That holds only for `FlowResultRoute` destinations, so D1 should go into F-0049 / F-0048 before the guard task.
- Plan 01 §4.2 and F-0048 still need the TL-owned sentences the engineer listed (decision 2 in the task file).
- Probe sources are kept as `.txt` (they were removed from the tree after the run):
  - [verifier_probe_test.dart.txt](verifier/verifier_probe_test.dart.txt)
  - [verifier_flow_probe_test.dart.txt](verifier/verifier_flow_probe_test.dart.txt)
  - [v0_running_probes_test.dart.txt](verifier/v0_running_probes_test.dart.txt)
  - [v1-v4_cold_template.dart.txt](verifier/v1-v4_cold_template.dart.txt)
  - results in [probe_results.txt](verifier/probe_results.txt).
