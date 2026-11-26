# Verification report: T-0041 `comics_details` exemplar (SC), favourite, publishing wiring

- **Verifier:** crew: Verifier, Opus tier (a fresh agent; not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0041-comics-details` @ **`59a88ed`**, a detached checkout in the Verifier's own worktree (merge base with `origin/main`: `0d395d8`)
- **Simulator:** `mc-T-0041-verifier-55504` (iPhone 17 Pro, iOS 26.2), created and deleted by `tool/e2e_ios.sh` (`SIMULATOR_DELETED_AT` in the log; `xcrun simctl list devices | grep -c mc-T-0041-verifier` → `0`). No shared simulator was touched.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0041-verifier`; every test run used `--nocache_test_results`; the server was shut down at the end.
- **Verdict: FAIL.** One Medium defect in the core of AC6 (Issue 1): after `requestSignIn()` the favourite re-reads the flag, but it does not check that the session is still the one it read for before it writes. A sign-out or another user's sign-in during that read still produces a `PUT`, and in the second case the favourite is saved for the other user. Every other AC and gate passes on my own runs. The other issues are Low.

My evidence is in [`verifier/`](verifier/). Links are relative to this file.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates (AC8) | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0041-verifier tool/checks/T-0041-AC8_gates.sh --role verifier` | **PASS**, every row ([gates.md](verifier/gates.md)): `test //...` 111/111 (touched packages uncached first), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures check, relative paths, fixtures closure, both byte identities, cutoff, not committed, gen-l10n parity, coverage |
| Byte identity (build_runner, my run) | `T-0041-AC7_matches_build_runner.sh`, `T-0032-AC6_matches_build_runner.sh` | comics_details **12 of 12 EQUAL**, characters_list **14 of 14 EQUAL**, nothing extra ([cd](verifier/byte_identity_comics_details.md), [cl](verifier/byte_identity_characters_list.md)) |
| Cutoff (body edit) | `T-0041-AC7_cutoff.sh` | PASS: config and API `.g.dart` unchanged, positive controls ran, no aggregate or retrofit spawn ([cutoff_body.md](verifier/cutoff_body.md)) |
| Cutoff, my outline edits | [controls.sh](verifier/controls.sh) §4 | **A** new method on `ComicsDetailsApi`: the retrofit part and API combine re-ran (`cacheHit=False`), `api.g.dart` changed; the API's injectable shard re-ran but its output was unchanged, so the aggregate stayed a cache hit (correct). **B** `ComicDetailsBloc` `@injectable` → `@lazySingleton`: the bloc shard and `DartAggregateCodegen //…:di_config` re-ran, `.config.dart` changed, retrofit stayed a cache hit ([controls.log](verifier/controls.log)) |
| Coverage, my own parser | `bazel coverage` of comics_details, publishing_wiring, characters_list, then [lcov_union.py](verifier/lcov_union.py) (maps `package:` URIs, unions DA lines, excludes generated files) | comics_details **376/376**, publishing_wiring **93/93**, characters_list **219/219** = 100 % ([coverage.txt](verifier/coverage.txt)). The lib files in no report are declaration-only (barrel, abstract API, navigator interface, root-import const, freezed state parts, the `PublishingRouteTargets` interface). Equals the engineer's figures |
| T-0038 gates | `T-0038-AC4_gates.sh` | PASS; `mc_fixtures_comics` 244/247 = 98.8 % ([t0038_ac4.md](verifier/t0038_ac4.md)) |
| L4 E2E | `tool/e2e/prepare_pub_project.sh --app app/mini_client` (34 generated files), then `tool/e2e_ios.sh --task T-0041 --role verifier` with 4 targets | `comics_journey_test` PASS 52 s, `comic_deeplink_test` PASS 27 s, `characters_journey_test` PASS 29 s; my probe target FAIL, a probe timing artefact explained below ([e2e-summary](verifier/e2e/e2e-summary.md); only 4 screenshots are kept) |

## Acceptance criteria
| AC | Mapped test(s) / checkpoint | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0041-AC1 | `:bdd_test` "The comic shows its cover…", "The facts are formatted for English", "…list the comic's credits" | Yes. The header step compares the title, the app bar title and the decoded bundled asset with the fixture record. `the fact X reads Y` compares exactly the row's two texts. The cast step derives its expectation from `characterIds` and the characters fixture, not from the new `characters` summary, and checks each card's art. It also asserts 0 requests to `/v1/characters/:id`. Killed: wrong comic (V01), missing Pages row (V02), German dates in en (V03), cast art (V19), the engineer's AC1-b | **PASS** |
| T-0041-AC2 | Outline × 4 failures with Retry; "A double Retry sends one request"; "An unknown comic shows that it was not found" | Yes. Killed: Retry dispatching `openCover` instead of `load` (V05), an unknown id throwing (V06), AC2-a, AC2-c | **PASS** |
| T-0041-AC3 | BDD cast/creator taps (`called(1)` + `verifyNoMoreInteractions`); `routes_test` push + Back; `comic_route_test` in the app | Yes. AC3-c killed; e2e `17_cast_member_placeholder` seen | **PASS** |
| T-0041-AC4 | German sections, `3,99 $`, `10. Jan. 1988`, roles, favourite labels and error; `en_XA` "nothing overflows" on every section, the cover, not-found and the favourite error | Yes. Killed: German price as English (V04), AC4-b | **PASS** |
| T-0041-AC5 | e2e journey and deep link on my simulator; `routes_test` (route, bad ids, initializer, drift); `comic_route_test`; characters_list related-comics BDD | Yes. Every screenshot looked at (below). Back navigation comic → preview → list probed on the device (`v01`, `v02`). Killed: V16 (route builds the wrong id), V17 (related comics `limit` + 1), AC5-c | **PASS** |
| T-0041-AC6 | `comics_details_favourite.feature` (real `mc_api_auth`, session and identity fixtures through `McTestContainer`); `routes_test` sheet tests | The listed scenarios are real and the mutations die: V07–V11, V13, V15, V20, AC6-b/e/f, R7-a/b, R8-a/c/d. But the post-sign-in read is not session-checked before the write (Issue 1, reproduced by probes P3 and P4) | **FAIL** |
| T-0041-AC7 | `:architecture_test`, `mc_arch_check`, byte identity, cutoff, not committed, fixtures checks | Yes. Negative controls: a `String label()` on `PublishingRouteTargets` → `mc_arch_check: 1 violation … [R15]`; `mc_fixtures_media` planted in `mc_fixtures_characters` → the T-0041-AC1 closure FAILs (sky_engine in both closures); `mc_fixtures_comics` planted in comics_details' production deps → T-0031-AC6 FAILs. Each passes again after restore. R3 and AC7-a killed | **PASS** |
| T-0041-AC8 | Gates script, coverage, traceability | Yes. AC tags in test names and features: AC1 9, AC2 5, AC3 5, AC4 10, AC5 19, AC6 21, AC7 15, AC8 3 | **PASS** |

### AC6 in detail (the core)
Green and mutation-proven: signed out → `requestSignIn()` awaited with no request while it is pending → one `PUT` that reached the backend with the reader's bearer (`RecordedRequest.headers`, after every interceptor) → `DataChanged('favourites')` exactly once. Cancel → no request to `/v1/me/**`. A double tap, signed in or out, sends one request. The toggle is optimistic, with a rollback and an inline error for add and for remove. A sign-out elsewhere and a rejected refresh reset the button to Add. A sign-in elsewhere reloads it. A user who already has the favourite gets no write after sign-in. A `_load` read that outlived its session is redone.

My race probes ([feature](verifier/probes/zz_verifier_probe.feature), [results](verifier/probes/probe_run.txt); temporary files, removed afterwards):
- **P1, a sign-out during an in-flight PUT:** correct. The PUT was already sent with the bearer and succeeded: one `DataChanged`, and the favourite is stored for the reader. Afterwards the toggle shows Add with no error, signed out.
- **P2, a tap during a session refresh** (PUT 401 once, refresh held, two taps): correct. The taps are ignored (the toggle is disabled). After the refresh there are 2 PUTs (the original and the replay), 0 DELETEs, 1 refresh and 1 `DataChanged`, and the favourite is saved.
- **P5, a switch to another user elsewhere:** correct. The toggle shows the collector's flag, and a tap writes for the collector with no DELETE.
- **P3 and P4: defect, Issue 1.**
- **Two pages of the same comic:** the lower page goes stale (Issue 5). This only happened with a programmatic `router.push`: a link to the same comic replaces the stack, so the UI cannot stack two pages today.
- **The sheet** ([widget_probes.diff](verifier/probes/widget_probes.diff)): Back and a barrier tap are refused while signing in (`routes_test`, and Back on the device). **A real drag (`tester.drag` 500 px) does close the sheet while signing in.** The answer is still the real outcome (`true`, signed in), so the documented fallback works. See Issue 3.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none on `main`. The two removed scenarios ("A character the backend no longer knows…" and "A failed cast member fails the comic…") only ever existed on this branch. The behaviour they tested is gone: `ComicsDetailsApi` has no character endpoint (4 methods: comic plus favourite GET/PUT/DELETE), the repository makes one request, and BDD asserts `0 requests for GET /v1/characters/:id`. The feature tests no longer serve the characters domain, so any such request fails the strict harness.
- **Existing tests changed (none weakened):**
  - `isolation_test` counts 8 → 9 initializers (exactly the new `FormattersDIInitializer`).
  - `comics_test`'s detail key set gains `characters`, which is stricter.
  - `T-0038-AC4_gates.sh`'s positive control moves to `mc_fixtures_media`, still Flutter-bound. It still has markers (`@flutter_sky_engine`), and the check passes.
  - Also changed, and fine: characters_list's `architecture_test` (expects `ComicId` in the barrel), its Background and golden test (also serve `comics.default`, because the preview now asks for comics), the universe_sandbox fakes (renamed to `UniverseRouteTargets`, plus `openComic`), and `T-0032-AC6_matches_build_runner.sh` (3 more files, stricter).
- **Lint suppressions added:** none. No `// ignore`, `ignore_for_file` or `skip:` lines added (`git diff origin/main...HEAD`).
- **Golden files updated:** only `characters_list/.../character_preview.png`, for the related comics section. The 5 new comics_details goldens pass.
- **Contract change:** `CONTRACT.md` documents `characters` (same order, the exact `{id, name, thumbnail}` served for the same seed). Only the `detail.json` snapshot changed. The drift test compares every summary with `GET /v1/characters/:id` for seeds 42 and 7. My V18 (names upper-cased) and R2-a are killed by the snapshot test. T-0038's tests are intact and its gates pass.
- **Mutations:** **35 of 37 killed** by a failing test, none by a compile error ([mutations.sh](verifier/mutations.sh), [log](verifier/mutations.log)). 20 are my own (V01–V20) and 17 are re-runs of the engineer's (AC1-b, AC2-a, AC2-c, AC3-c, AC4-b, AC5-c, AC6-b, AC6-e, AC6-f, R7-a, R7-b, R8-a, R8-c, R8-d, R2-a, R3, AC7-a). The 2 survivors are test gaps (Issues 2 and 4).

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Comic page (AC1, AC5) | [13_comic_page.png](verifier/e2e/13_comic_page.png) | App bar with Back and "Amber Requiem #8"; cover, title, "Issue #8", "Add to favourites"; Synopsis; Details `#8`, `$4.99`, `32`, `Aug 11, 2016`; Creators with roles; Characters starting | yes |
| Favourite saved after sign-in (AC6) | [15_favourite_saved.png](verifier/e2e/15_favourite_saved.png) | The sheet is gone; "Remove from favourites" (secondary style) | yes |
| Deep link `miniclient://app/comics/501500` (AC5) | [18_deep_link_comic.png](verifier/e2e/18_deep_link_comic.png) | "Amber Frontier #1" at the root, `$3.99`, `Jan 10, 1988`; no back button (a flow root, F-0035, accepted) | yes |
| Back from the comic page (AC5) | [v01_back_to_preview.png](verifier/e2e/v01_back_to_preview.png) | Back returned to the Amber Alchemist preview with its Comics list; a second Back returned to the grid (`v02`, not kept) | yes |

I also looked at, without keeping them: 10–12 (home, list, preview with 5 related comics), 14 (the sheet: "Sign in as Rhea Reader…", Sign in / Not now), 16 (cast card with art), 17 (`Character details 100486`, with Back), 19 (a link to the running app opens "Spindle Chronicles #1"), 20 ("Not found — Nothing lives at miniclient://app/comics/abc", no crash), 01–04 (the T-0033 journey), and v02/v03.

The probe target's failure is an artefact of my probe. With `latencyMs: 0` the sign-in finished before my Back, so my Back popped the comic page instead of the sheet. My drag then scrolled the preview (v03), and the wait for "Remove" timed out. The log shows `_Toggle _Ready -> _Ready` with the PUT 200 before that. The busy-sheet behaviour was therefore probed deterministically at widget level instead (above).

## Conformance (what the bricks would copy)
- The shapes match characters_list and plan 01 §3.3: the barrel exports exactly the Flow, the Navigator and 3 extension-type ids, each with `show`. The DI initializer is in Tide's verbatim shape. `flow_scope.dart` is hand-written (as T-0032). The retrofit API is `@injectable` with relative paths. The repository is stateless and returns `Result`. Both blocs are sealed freezed states read with `when`, with failures implementing `McFailureState`. Only blocs call the navigator. The pages are `McAppBar(leading: const McFlowBackButton())` with `McSectionHeader`.
- **The temporary sign-in sheet lives only in `publishing_wiring/lib/src/sign_in/`.** The feature imports no fixture, no `mc_api_auth` and no sheet; those are dev dependencies only.
- **`FormattersDIInitializer`** sits in `rootInitializers` after `ApiAuthDIInitializer`, last before `RouterDIInitializer` and the wirings. That is plan 01's `L10nCoreDIInitializer` slot, and `formatters_root_test` pins it. It is also in `McTestContainer`.
- Divergences worth fixing before the bricks copy them are Issues 1, 5 and 6.

## Issues found
1. **(Medium) The post-sign-in re-read is not session-checked before the write.** `feature/comics/comics_details/lib/src/presentation/bloc/comic_favourite_bloc.dart:139-159`. After `requestSignIn()` returns true, `_toggle` notes `epoch`, awaits `isFavourite`, then sets `_shownEpoch = epoch` and writes, without comparing `_session.epoch` to `epoch`. `_load` does compare (lines 114-116); this second read path does not. That breaks review item 8 ("a read that outlived its session is redone"; no PUT based on stale state).
   - **P3:** tap Add (signed out), sign in, hold the GET, sign out elsewhere, release. Result: `PUT /v1/me/favourites/comic/501500` is sent with no session and answered 401. The UI ends right (Add, no error).
   - **P4:** the same, but `collector@…` signs in elsewhere during the held GET. Result: the PUT goes out **with the collector's bearer**, the favourite is saved for the collector (the reader's read decided it), and `DataChanged` is published.
   - **Fix:** return when `_session.epoch != epoch` after the fresh read, and set `_shownEpoch` only after that check (the existing post-tap check then reloads). Add P3/P4-shaped scenarios.
   - Reproduce: copy [zz_verifier_probe.feature](verifier/probes/zz_verifier_probe.feature) and [the step](verifier/probes/the_backend_fails_with_once.dart.txt) into `test/feature/` and run `:bdd_test`. P3 and P4 as committed there assert the *observed* (defective) outcome.
2. **(Low, test gap) "Not now" being disabled while signing in is untested.** `app/wiring/publishing_wiring/lib/src/sign_in/fixture_sign_in_sheet.dart:134-136`. V14 (Not now always enabled) survives. The code is right, but a regression would make Not now during a sign-in answer false while the sign-in completes. A signed-in user would then be reported as having backed out, which is what review item 7 is meant to prevent. Assert it in the "barrier and Back" test.
3. **(Low) A drag dismisses the sheet while signing in.** `fixture_sign_in_sheet.dart:27-31`: `showModalBottomSheet` keeps `enableDrag: true`, and `PopScope` does not stop a drag on Flutter 3.47.7. A real `tester.drag` closed it. The outcome stays correct (the code's documented fallback, `R7-b`), so "can't be dismissed while signing in" holds for Back and the barrier only. The sheet is temporary (P-044), so either accept this or pass `enableDrag: false`. Note that `routes_test`'s "closed anyway" test uses a direct `Navigator.pop`, not a drag.
4. **(Low, test gap) The `saving` flag's disabled button is untested.** V12 (`ready(favourite: wanted)` without `saving: true`) survives. Double taps are still guarded by `_busy`, which is tested, so this is defence in depth.
5. **(Low) Two open pages of the same comic disagree.** The favourite bloc does not listen to `DataChanged('favourites')`, the topic it publishes itself. After the top page removes the favourite, the lower page still shows "Remove". Tapping it sends an idempotent DELETE and shows Add, with no error. This is not reachable through the UI today. It is a pending-work candidate for the SC bricks (re-read on its own topic).
6. **(Low, conformance) Small things the bricks would copy:**
   - `RelatedComic.cover` is mapped but never rendered: the preview's rows are `ListTile(title:)` only (`feature/characters/characters_list/lib/src/presentation/widget/related_comics.dart`).
   - `_FactRow` uses a literal `EdgeInsets.symmetric(vertical: 6)`, not a spacing token (`feature/comics/comics_details/lib/src/presentation/widget/comic_facts.dart:60`).

## Notes for the Tech Lead
- The known and accepted items were not counted against the task: the T-0042 glob exclusion, `characterIds` kept, the `/creators/:id` placeholder, and the prefixed route targets.
- A re-verification can be narrow: Issue 1's fix plus its scenarios, re-running probes P1–P5, mutations R8-a/c/d, V07/V08 and the gates. Issues 2–6 can go to pending-work if you prefer.
- `architecture_test` takes about 113 s in both features under `coverage`, a large share of the run.
