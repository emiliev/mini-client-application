# Verification report — T-0050: `mc_api_auth` pins a request to its session epoch from the first send

- **Verifier:** crew: Verifier, Opus tier (fresh agent, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0050-auth-first-send-pin` @ `db556b5` (includes `origin/main` at a411c59)
- **Simulators:** `mc-T-0050-verifier-55375` (branch) and `mc-T-0050-verifier-86320` (merge result), iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted both; `xcrun simctl list devices | grep -c mc-T-0050` → `0`. I didn't touch any shared simulator.
- **Bazel:** `/tmp/mc-ob-T-0050-verifier` (my worktree: gates, merge check) and `/tmp/mc-ob-T-0050-verifier-probe` (a scratch worktree at `db556b5` at `/tmp/mc-T-0050-verifier-probe`, for probes and mutations). Both were shut down at the end.
- **Verdict:** **FAIL.** One defect blocks the merge: **D1** (Medium). It is a new AC1 test that fails 3 to 10 % of runs because of a teardown race in the test. The product behaviour is right on every AC. I re-derived every claim, and all my probes and mutations agree with the engineer's. The fix is local to the test, and I confirmed it holds over 200 runs. A narrow re-verify should be enough.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| AC4 gates script | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0050-verifier tool/checks/T-0050-AC4_gates.sh` | **PASS**, all 17 rows ([T-0050-AC4_gates.md](verifier/T-0050-AC4_gates.md)): `test //...` (touched packages uncached, then 153 of 153), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, the fixtures check, relative paths, and the T-0041-AC7 and T-0048-AC7 byte identity, cutoff, not-committed and gen-l10n parity checks |
| Coverage, my own parser | [`vcov.py`](verifier/vcov.py) over each package's own `coverage.dat`. It also lists every hand-written `lib/` file that no LCOV mentions | `mc_api_auth` 124/124 (100 %), `mc_session` 92/92 (100 %), `mc_forms` 286/286 (100 %), `comics_details` 401/401 (100 %), `library_reading_list_editor` 734/744 (98.66 %). The files no LCOV mentions are barrels, abstract APIs or navigators, freezed `part` files and const-only `flow_scope.dart`, so none holds executable code. Line 327 of the editor bloc, the unreachable `epoch == null` return from review item 3, is among the missed lines, as the task file says |
| L4 E2E (branch) | `tool/e2e/prepare_pub_project.sh` then `tool/e2e_ios.sh --task T-0050 --role verifier` | **9 of 9 PASS** ([summary](verifier/e2e-summary-branch.md)) |
| Flake check | `--runs_per_test=25/100/200 --nocache_test_results` on the timing-sensitive new targets | `comics_details:bloc_guards_test` 25/25, `library_reading_list_editor:bloc_guards_test` 25/25 and `session_di_test` 100/100 pass. **`mc_api_auth:auth_pin_test` fails 3/100 when the machine is idle and 10/100 under load (D1).** `auth_races_test` failed 1/100, in a pre-existing T-0039 test (D4) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0050-AC1 | A pinned request plus a session change before the send: nothing reaches the backend, and the caller gets the documented failure. Unpinned requests are unchanged | `mc_api_auth:auth_pin_test` (10 tests), plus the T-0039 tests (unchanged, green) | **Yes.** The tests use real Dio, the real `Session` and the mocked backend, and assert on `recentTraffic`. With the guard reverted (`&& false`), 4 of 10 fail, the same 4 the engineer reported. **My probes** ([verifier_pin_probe_test.dart](verifier/verifier_pin_probe_test.dart), 9 tests, all green on `db556b5`; 6 go red with the guard reverted) cover these cases. (V1) The pin goes stale **inside the chain**, from a hook placed just before `AuthInterceptor`: 0 requests reach the adapter. (V2) It goes stale **during a refresh**, because B signs in: no replay, and B's bearer is never sent. (V3) It goes stale **between the refresh and the replay** (a sign-out): the pin rejects the replay, and 1 PUT goes out. (V4) A **5xx retry keeps the pin**: after a sign-out during the retry delay there is no anonymous retry. (V5) **`copyWith` keeps the pin**: both `copyWith()` and `copyWith(extra: {...extra})` hold it, and a `Dio.fetch` of the copy after a switch is rejected with 0 requests. (V6) **A refresh does not change the epoch.** (V7) The rejected request reaches neither the retry nor the refresh. Dio's `reject` without `callFollowingErrorInterceptor` skips every error interceptor (`dio_mixin.dart`, `errorInterceptorWrapper`). (V8) A re-sign-in as the same user also invalidates the pin (conservative). (V9) A pin that is not an `int` is ignored. **The real root Dio** ([verifier_root_dio_probe_test.dart](verifier/verifier_root_dio_probe_test.dart), through `rootInitializers`) has the order `[ImplyContentTypeInterceptor, MonitoringInterceptor, RetryInterceptor, AuthInterceptor]` with `MockBackendHttpAdapter`. Auth is last, so no other interceptor and not the adapter can send before the check, and the race on this Dio sends 0 requests. `skipAuthKey` and unpinned requests are unchanged (K4 and K5 are killed). **D1:** this target is flaky | **PASS on behaviour.** The test target is flaky (D1) |
| T-0050-AC2 | In each caller, the race scenarios send no request for the wrong user, asserted on the backend's traffic | `comics_details:bdd_test`: the PUT and DELETE race scenarios. `comics_details:bloc_guards_test`: the stale shown epoch. `library_reading_list_editor:bdd_test`: POST, first write and second write. `:contract_test`: every write is pinned and no read is | **Yes.** I read the diff: the comics PUT and DELETE, the reading-list create, the details PUT and the items PUT pass `authPinned(epoch)`, and `getFavourite`, `fetchList` and `searchComics` don't (the contract test asserts exactly that map). **Hook placement:** the step inserts at index 0. My mutation M10 moves it after auth, and all 5 AC2 scenarios go red, so the step really exercises the pre-auth window. **Without the pins (BDD only, no contract test):** M11 (the create) and M12 (the items PUT) kill the matching race scenarios, and the engineer's C1 and C2 kill the comics ones. **Favourite race orders** ([verifier_favourite_probe_test.dart](verifier/verifier_favourite_probe_test.dart)). (VP1) When `_SessionChanged` reloads first and the tap comes after, B's tap writes (1 PUT, state `favourite: true`). (VP2) In the race order the tap is dropped (0 writes), and a later tap goes through (1 PUT), so the guard doesn't drop every tap after a switch. (VP4) A sign-out followed by a tap writes nothing. **Negative controls:** I ran the engineer's `negative_control.sh` myself, and both variants went red, B through the teardown check "never signed in". My own control on the editor (`vnc.sh`: the "first write" scenario with a wrong route, `session belongs to` removed and the tap kept) went red | **PASS** |
| T-0050-AC3 | P-080, P-089 and P-093 are closed. Each item has a test and a mutation | `auth_races_test` (P-080 ×2), `session_di_test`, `comics_details:bdd_test` (P-089 ×5), `library_reading_list_editor:bloc_guards_test` (P-093), `mc_forms` (2), `:bdd_test` l10n (German, en_XA) | **Yes.** **P-080:** the shared refresh is keyed per session (P80-a, from the engineer's log; I didn't re-run it). A replay after a local sign-out is not sent (P80-b re-run: killed). The epoch after a refresh is unchanged (my V6, and the pinned `[401, 200]` replay test). **P-089:** the guard is keyed by `(kind, id)` (`comic_details_bloc.dart:101-112`). I re-ran P89-c (400 ms, so 499 ms opens again) and P89-f (one window for all targets, so a different target at 450 ms is dropped): both killed. The 501 ms and creator scenarios exist and their mutations are logged as killed. **P-093:** I re-ran V03, V20-b and V23. V03 and V23 are killed. V20-b survives, and I confirmed it is equivalent: `_load`'s only callers are `_start` (once, before any `loadFailed`) and `_Retry` when `state is _LoadFailed`, and `_load` emits `loading` synchronously before its first await, so a second Retry is always stopped by the state check. **en_XA screenshots at 1× and 2×**, rendered by my own golden probe ([verifier_xa_golden_test.dart](verifier/verifier_xa_golden_test.dart)): see Visual acceptance | **PASS** |
| T-0050-AC4 | Gates, ≥ 90 % coverage, byte identity and cutoff for both features, and the mini_client e2e passes | Gates script, my LCOV parser, e2e | **Yes.** See the gates above. The e2e passes 9/9 on the branch and 10/10 on the merge result | **PASS**, but D1 makes `test //...` pass only by luck (3 to 10 % red) |

## Mutations
- **Engineer's, re-run** ([engineer_mutations_sample.log](verifier/engineer_mutations_sample.log), their script with `MC_ONLY`, in my probe worktree). The baseline of 16 targets passes. I re-ran 12 of 38: K2, K5, P80-b, C3, C5, H1, P89-c, P89-f, R1-b, P93-V03 and P93-V23 are **killed**, and P93-V20-b **survives**, as declared (equivalent, confirmed above). **12 of 12 behave as expected.**
- **My own** ([vmut.sh](verifier/vmut.sh), [verifier_mutations.log](verifier/verifier_mutations.log)): 12 mutations aimed at the interceptor and the guards.

| ID | Mutation | Result |
|---|---|---|
| M1 | The pin is compared with the epoch the bearer was applied for, not the session's | killed (4 AC1 tests) |
| M2 | A stale pin is sent without a bearer instead of being rejected | killed (4 AC1 tests) |
| M3 | Only the first send is held to the pin (replays and retries exempt) | **survived the committed tests**; killed by my V3 and V4 (D2) |
| M4 | `authPinned` stores the epoch as a `String` (silently unpinned) | killed (5 AC1 tests) |
| M5 | Favourite: `_shownEpoch` is not updated after a sign-in from the tap | killed (3 T-0041-AC6 scenarios: the new drop guard would eat the sign-in-then-save) |
| M6 | Favourite: no reload at the end of a tap whose session moved on | killed (3 T-0041-AC6 scenarios) |
| M7 | The editor's create pins `_session.epoch` instead of the checked `epoch` | survived, **equivalent as expected**: there is no await between `_canWrite(epoch)` and the call, so the two values are always equal |
| M8 | Open guard: the timer is not cancelled in `close()` | survived. Harmless: the callback is empty and `mcSettle` outlives 500 ms (observation) |
| M9 | Open guard keyed by id only, so a creator whose id equals a recently opened character's is dropped | **survived** (D3, test gap) |
| M10 | The race step's hook is moved to the end of the chain (after auth) | killed (all 5 AC2 scenarios) |
| M11 | The editor's create is not pinned, BDD only | killed (the POST race scenario) |
| M12 | The editor's items PUT is not pinned, BDD only | killed (the second-write race scenario) |

## Merge check (`git merge --no-ff origin/main` at bcc6ae1, not committed, then `git merge --abort` back to `db556b5`)
- The merge is clean: no conflicts, 116 files from T-0049.
- `tool/bazelw … test --lockfile_mode=error //...`: **155 of 155 pass** (24 executed; the rest are cached on unchanged inputs).
- e2e on the merge result: **10 of 10 PASS**, including T-0049's new `character_details_deeplink_test` ([summary](verifier/e2e-summary-merge.md)).
- **Semantic interactions, none harmful.**
  - `AppFlows._open` now ends the caller's wait with null when the editor's route is disposed without a result.
  - A pinned editor write rejected after a switch ends in `_end` → `sessionEnded` → Close → `_flow.complete()` with no list, so AppFlows gets null, as for a declined sign-in.
  - If a `go` replaces the editor while a pinned write is in flight, that write keeps the same, still-current epoch and goes out under the same user's bearer. The bloc's `isClosed` checks then stop the second write, which is unchanged from T-0048.
  - T-0049's route nesting doesn't touch the favourite's or the editor's repositories.

## Test-integrity audit
- **Every AC has a `T-0050-ACn` test:** AC1 in `auth_pin_test`; AC2 in two BDD features, `bloc_guards_test` and the contract test; AC3 in `auth_races_test`, `session_di_test`, the BDD files, `bloc_guards_test` and `mc_forms`; AC4 in `tool/checks/T-0050-AC4_gates.sh`.
- **Tests deleted, skipped or weakened:** none. There are no removed `test(`, `Scenario` or `group(` lines and no `skip`. The contract test's six calls gained `epoch: 0`. That is a signature change, and there is no auth interceptor in that test (accepted, as the brief says). The steps `I tap the cast member` and `I tap the creator` moved onto `tapComicTarget` with the same scroll, the same hit-test expectation and the same settle.
- **Lint suppressions:** none (the only match for `// ignore:` is the sentence in the task file).
- **Goldens:** none changed (the only PNGs in the diff are under `documents/evidence/`).
- **New dependencies, all justified.**
  - `mc_api_auth` is now a runtime dependency of both features, because their repositories call `authPinned`. It is pure Dart, so R15 holds, and `mc_arch_check` passes.
  - `mc_storage` is a dev dependency of the editor (`FileStore` in `bloc_guards_test`).
  - `dio ^5.11.0` is a dependency of `mc_test_steps` (the hook). `rules_fork.sh check` passes, so the lock is consistent.
- **Full diff reviewed** against `origin/main`: lib, tests, BUILD files, pubspecs, the gates script and documents.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| AC3 en_XA not-found, 2× (my golden probe, 402×874) | `documents/evidence/T-0050/verifier/xa_not_found_2x.png` | The app bar "[Ŕéàðíñĝ ļíšţ ~~~~~]", an inbox icon, the bold title "[Ļíšţ ñóţ ƒóúñð ~~~~~~]" over two lines and the grey body "[Ţĥíš ŕéàðíñĝ ļíšţ ðóéš ñóţ éxíšţ óŕ íš ñóţ ýóúŕš. ~~~…]" over four. Everything is pseudo-text and wraps, with no clipping or overflow stripe. The 1× version (not committed) shows the same text on one or two lines | yes |
| AC3 en_XA failed load, 2× | `documents/evidence/T-0050/verifier/xa_load_failed_2x.png` | A red "!" icon, the title "[Ţĥé ŕéàðíñĝ ļíšţ çóúļð ñóţ ƀé ļóàðéð ~~~]" over three lines, the body "[Ţĥé šéŕvéŕ ĥàð à þŕóƀļéɱ. Þļéàšé ţŕý àĝàíñ ļàţéŕ. ~~~]" and a red "[Ŕéţŕý ~~]" button. Nothing is English and nothing overflows. The app bar title keeps the same size at 1× and 2× (as before this task; nothing clips) | yes |
| e2e: the pinned favourite PUT goes out for the signed-in user | `documents/evidence/T-0050/verifier/e2e_15_favourite_saved.png` | "Amber Requiem #8" after signing in from the sheet: the toggle reads "Remove from favourites", so the pinned write was sent and saved | yes |
| e2e: the pinned create POST goes out, and the result reaches home | `documents/evidence/T-0050/verifier/e2e_36_home_list_created.png` | Home shows "List created: l-5" and an "Edit list l-5" button | yes |

## Issues found
1. **D1 (Medium, blocks the merge): `auth_pin_test` is flaky, because of a teardown race in the new test.**
   - **Where:** `utility/mc_api_auth/test/auth_pin_test.dart:21-24`. `_signInNow` and `_signOutNow` call `.ignore()` on the session's save.
   - **Why it fails:** `tearDown(() => rig.dispose())` at line 33 runs while that save is still writing, and `Rig.dispose` (`test/rig.dart:161`) calls `dir.deleteSync(recursive: true)`. The result is `FileSystemException: Deletion failed … Directory not empty (errno 66)`.
   - **Rate:** **3/100** runs fail when the machine is idle, and **10/100** under load (`--runs_per_test=100 --nocache_test_results`). The failures were in "unpinned requests are unchanged" (6), "rejected after a sign-in" (3) and "skips auth" (2). Every one was the teardown error, never an assertion.
   - **Fix (confirmed by me in the probe tree, then reverted):** keep the futures (`_saves.add(rig.session.signIn(...))`) and `await Future.wait(_saves)` in `tearDown` before `dispose`. With that, **0/200** runs fail.
   - **Repro:** `tool/bazelw test --runs_per_test=100 --nocache_test_results //utility/mc_api_auth:auth_pin_test`.
2. **D2 (Minor, test gap): no committed test shows that a replay or retry keeps the pin** (mutation M3, `auth_interceptor.dart:66`).
   - If a replay or retry is exempted from the pin, every committed test still passes. With B signed in, the older `ours` epoch check still stops it, so B's bearer never leaks. After a sign-out, though, the request goes out anonymously, which contradicts the class doc ("rejected before any bearer is attached and never reaches the backend").
   - My probes V3 (a sign-out between the refresh and the replay) and V4 (a sign-out during a 5xx retry delay) kill M3 and pass on `db556b5`.
   - Suggest committing them, together with V1 (the pin goes stale in front of auth) and V5 (`copyWith`), to `auth_pin_test`.
3. **D3 (Minor, test gap): the open guard's key is not pinned on its `kind` half** (mutation M9, `comic_details_bloc.dart:105`). Keying by id alone would drop a creator tapped within 500 ms of a character with the same numeric id, and no scenario catches that. Suggest a "character then creator with the same id" unit or BDD case, or accept it as it is.
4. **D4 (Low, pre-existing, not T-0050): a T-0039 race test depends on wall-clock time.** `auth_races_test.dart:161` ("a request retried after B signed in …") failed 1 in 100 runs under load with "expected a failure". It relies on a 10 ms delay racing a 50 ms retry delay. T-0050 doesn't change it (`auth_races_test` only gained tests, and the request is unpinned). Suggest a pending-work item.

## Notes for the Tech Lead
- **Observation, same-user re-sign-in.** `Session.signIn` bumps the epoch for the same user without announcing it. After that, the favourite's first tap is dropped silently, the end of the tap reloads, and the second tap writes (VP3). No UI path signs the same user in again today; if one appears, the drop could show feedback. The editor already treats that case as `sessionEnded` (since T-0048).
- **Observation, logging.** A pinned request rejected by the interceptor is not logged by `MonitoringInterceptor`, because `reject` without `callFollowingErrorInterceptor` skips every error interceptor. The older "retry across a session change" rejection already behaves the same way.
- **Re-verify.** A narrow Sonnet re-verify for D1 is enough: `auth_pin_test --runs_per_test=200 --nocache_test_results` green, plus `T-0050-AC4_gates.sh`. D2 and D3 can go with that fix or to `pending-work.md`.
- **Evidence.** Everything is in `documents/evidence/T-0050/verifier/`. The probe tests, `vmut.sh`, `vnc.sh` and `vcov.py` are there to read; they are not wired into Bazel.

## Re-verification at 3cf8359

- **Verifier:** crew: Verifier, Sonnet tier (fresh, narrow re-verify, ADR-0011). Bazel output base `/tmp/mc-ob-T-0050-reverify` (shut down at the end). Logs: `verifier/reverify_*.log`.
- **Verdict:** **PASS.** D1 to D4 are closed. No production file changed.

| Check | Result |
|---|---|
| **D1, 200 runs, idle** (`--runs_per_test=200 --nocache_test_results`) | `auth_pin_test` 200/200, `auth_races_test` 200/200 ([log](verifier/reverify_runs200_idle.log)) |
| **D1, 200 runs, under load** (8 `yes` busy loops, killed afterwards, 0 left) | `auth_pin_test` 200/200, `auth_races_test` 200/200 ([log](verifier/reverify_runs200_load.log)) |
| **D1, bloc_guards x50** | `comics_details` 50/50, `library_reading_list_editor` 50/50 ([log](verifier/reverify_bloc_guards50.log)) |
| **D1, code read** | `Rig.track` stores each save; `Rig.dispose` does `await Future.wait(_pending)` before `bus.dispose`, `session.dispose` and `dir.deleteSync`. `grep` for `.ignore()` and `unawaited(` over `utility/mc_api_auth/test`, `utility/mc_test_steps` and `feature/` (non-lib): **no matches** |
| **D2** | `auth_pin_test` has two new `T-0050-AC1` tests (replay after refresh, retry after 5xx). Each asserts exactly one PUT reached the adapter (`ArrivalAdapter.seen`) and `ApiUnauthorized`. **Mutation:** I exempted replays from the pin in `auth_interceptor.dart` (`&& options.extra[_applied] != true`). Both tests went red. Restored (`git checkout`) |
| **D3** | The `comics_details:bloc_guards_test` case "keys on the kind as well as the id" opens `CharacterId(7)`, then `CreatorId(7)`, and expects `['character 7', 'creator 7']`. **Mutation:** the guard compared the id only (`_openTarget?.$2 == target.$2`). That test went red (confirmed in `test.log`). Restored |
| **D4** | Diff `db556b5..3cf8359` of `auth_races_test.dart`: the removed lines are only the 10 ms sleep, the `api.signOut` and `_signInCollector` calls, and the `pending` plumbing. Every `expect` is untouched, and `expect(switched, isTrue)` is added. `ArrivalAdapter.fetch` calls `onArrive` synchronously before `inner.fetch` answers, so the sign-out and sign-in precede the 503 and the 50 ms retry |
| **Integrity** | `git diff db556b5..3cf8359 --stat` outside `documents/`: 6 files, all test code or test steps (`auth_pin_test`, `auth_races_test`, `rig.dart`, the two `bloc_guards` tests, `signs_in_just_before_the_app_sends.dart`). **No production change**, so no e2e |
| **Gates** | `T-0050-AC4_gates.sh`: **PASS**, 17 of 17 ([log](verifier/reverify_gates.log)). Note for the TL: in a fresh worktree the `dart format` gate fails with "Package resolution error ... mc_analysis" until `fvm dart pub get` has run at the root (the formatter then misses the page width). After `pub get` it is clean (784 files, 0 changed). This is an environment step, not a code defect |
| **Merge check** | `git merge --no-ff --no-commit origin/main`: clean. `test --lockfile_mode=error //...`: **155 of 155 pass** ([log](verifier/reverify_merge_test.log)). Merge aborted; the tree is back at `3cf8359` |

No new defects. Observations from the first report (same-user re-sign-in, unlogged pinned rejection) stay with the TL.
