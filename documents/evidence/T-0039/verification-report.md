# Verification report — T-0039: Auth slice (`mc_session`, `mc_api_auth`, `mc_fixtures_identity`)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0039-session-and-auth` @ `b40c159`
- **Simulator:** `mc-T-0039-verifier-64974`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it, and afterwards `xcrun simctl list devices | grep -c mc-T-0039` gives 0. The scratch pub copy `/tmp/mc-T-0039-verifier-e2e` is deleted.
- **Bazel:** `--output_base=/tmp/mc-ob-T-0039-verifier`, shut down at the end.
- **Verdict:** **FAIL** (AC2). AC1, AC3, AC4 and AC5 pass. AC2 fails on two counts. First, a refresh result is applied to whatever session is current when it lands, even when that is a different user's session (D1). Second, one of the four mutations the brief says must turn a test red, "refresh on 403", survives (D2).

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0039-verifier tool/checks/T-0039-AC5_gates.sh --role verifier` | **PASS** ([gates.md](verifier/gates.md)): test //..., lint, mc_arch_check, rules_fork.sh check, format, l10n_check, closure, fixtures check, coverage |
| Touched tests, uncached | `bazel test --nocache_test_results //utility/mc_session/... //utility/mc_api_auth/... //utility/mc_fixtures_identity/... //app/...` | **17/17 targets PASS**, 0 skips. Per target: interceptor +22, auth_api +13, identity +19, contract +14, session +18, session_di +5, no_flutter +1 ×3 |
| Coverage (my own parser, [cov.py](verifier/cov.py), union of the per-target `coverage.dat` files) | `bazel coverage` on the 3 packages | `mc_session` 85/85 **100 %**, `mc_api_auth` 92/94 **97.9 %** (missing `auth_interceptor.dart:50-51`), `mc_fixtures_identity` 128/130 **98.5 %** (missing `domain.dart:30,81`). Matches the engineer's numbers. ≥ 90 % |
| Closure, negative control | `@pub_deps//:flutter` added to `mc_session` `_DEPS` temporarily, then `T-0039-AC5_closure.sh` | **FAILS as it must** ([closure_negative.md](verifier/closure_negative.md)). `mc_session` and `mc_api_auth` (transitively) show Flutter markers, and `mc_fixtures_identity` stays clean. Reverted |
| Fixtures check, independent | `bazel query 'rdeps(//..., //utility/mc_fixtures_identity:mc_fixtures_identity)'` | Only test targets: `app_core:{boot,links_and_hooks,router_ref_and_scheme}_test`, `mc_api_auth:{auth_api,auth_interceptor}_test`. No production feature or DS target |
| L4 E2E | `tool/e2e_ios.sh --task T-0039 --role verifier` over a `prepare_pub_project.sh` copy: my [verifier_session_restore_t0039_test.dart](verifier/verifier_session_restore_t0039_test.dart) plus the 3 committed mini_client targets | **4/4 PASS**: restore probe 48 s, journey 30 s, deep link 26 s, link after flow 21 s ([e2e-summary](verifier/e2e/e2e-summary.md)) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0039-AC1 | Bearer present when signed in, absent when signed out | `auth_interceptor_test` "T-0039-AC1 …" (7), `auth_api_test` "T-0039-AC1 …" | Yes. `/v1/echo-auth` returns the header the server saw: `Bearer mc-access-u-100-5` when signed in, `null` when signed out, and it follows sign-in then sign-out. A header the caller set is left alone; a 5xx retry keeps the bearer. My probes: a sign-out during a retry backoff makes the retry go out with no header, and a sign-in as B during the backoff makes it carry B's token. A sign-out while a request is in flight triggers no refresh. Mutation M12 (prefix dropped) is killed | **PASS** |
| T-0039-AC2 | One refresh, one retry with the new token; 3 concurrent 401s, one refresh; a failed refresh signs out with `ApiUnauthorized` | `auth_interceptor_test` "T-0039-AC2 …" (15), `session_test` "T-0039-AC2 …" | The named scenarios are real: they make concurrent requests through the production `Dio` (monitoring, retry, auth) on the mocked backend and check traffic `[401,401,401,200,200,200]` with exactly 1 refresh. The late 401 is held by `/v1/gated`, and both failure-policy branches are tested. **But** D1: the refresh result is not tied to the session it was started for. **And** D2: "refresh on 403" survives the suite | **FAIL** |
| T-0039-AC3 | Fixture sign-in, wrong password 401, favourites persist until `reset()`, determinism, contract snapshots, rotation | `identity_test` "T-0039-AC3 …" (19), `provider_contract_test` (14) | Yes. A PUT shows up in GET and in `/v1/me` `favouriteCount`, survives a new sign-in, and is gone after `reset()`. One request sequence on two backends gives byte-identical output. The 11 snapshots match, and no snapshot exists without a case. A reused refresh token gets 401. The restart scenario ("a refresh token saved by an earlier run still works once") pins the counter skipping revoked numbers: mutation M9 is killed | **PASS** |
| T-0039-AC4 | Survives a new instance; a corrupt store reads signed out and heals; writes serialised | `session_test` "T-0039-AC4 …", `session_di_test` "T-0039-AC4 …" | Yes. A new instance restores the user and tokens, and updated tokens survive. `{broken`, seven wrong shapes and a corrupt store heal on sign-in and on sign-out. Saves are serialised twice over: `Session._enqueue` and `FileStore._serialised` per key. That makes M6 (drop `_enqueue`) an equivalent mutant, not a gap. Two instances on one key are documented as not seeing each other | **PASS** |
| T-0039-AC5 | Pure Dart, registered, ≥ 90 %, fixtures check, app boots, gates | `no_flutter_test` ×3, `session_di_test` "T-0039-AC5 …", `auth_api_test` "T-0039-AC5 …", `app_core:boot_test` "T-0039-AC5 the root list boots the session …", `T-0039-AC5_gates.sh`, `_closure.sh` | Yes. The closure check is real (negative control above). The new boot test (a plain `test`, so real async) signs in over the app `Dio`, reads `/v1/me` with the bearer, resets, boots again and sees `u-100`. M11 (always `Session.empty`) is killed by `boot_test` and `session_di_test` | **PASS** |

## Initializer order
New order: Config, Monitoring, Storage, **EventBus**, Session, MockedBackend, ApiClient, ApiAuth, Router, wirings.
- `EventBusDIInitializer` has no dependencies.
- `SessionDIInitializer` needs `FileStore` and `EventBus`, both earlier. Without them it throws (tested).
- `ApiAuthDIInitializer` needs `Dio`, `SessionReader` and `SessionWriter`, all earlier.
- `ApiClientDIInitializer` needs `AppConfig` and `Monitoring`, both earlier.

Nothing depends on a later registration. GetIt disposes in reverse order, so `Session` (stream close) goes before `EventBus`, which is fine. The app_core, mini_client and universe_sandbox tests all pass (8 targets).

## Boot read (TL decision: skip for a missing or empty store)
- **Unit level:** `session_di_test` covers a missing directory and an empty one (signed out, no read, the directory is not created) and a directory holding other keys (restores).
- **Real app on the simulator:** my e2e probe writes a session through `FileStore(appStorageDirectory())` before calling the real `main()`, then waits for home. Under `IntegrationTestWidgetsFlutterBinding`, which runs on real time, it asserts that `diContainer<SessionReader>()` is signed in as `u-100` with the saved token. **PASS** (48 s). So a populated store restores at boot in the real app and boot is not held up. The hang the engineer describes happens only under `testWidgets` fake async (F-0038 fact 1). It stays a trap for any future widget test that boots with a populated directory. The readSync follow-up is the right fix.

## Probes ([verifier_probe_test.dart](verifier/verifier_probe_test.dart), output in [probe_output.txt](verifier/probe_output.txt), run as a temporary Bazel target and then removed)
| Probe | Result |
|---|---|
| V-P1 10 concurrent 401s, zero latency, and V-P1b under realistic latency | 1 refresh, 10 × 200, traffic 10 × 401 then 10 × 200 — OK |
| V-P2 a replay that gets 401 again | 2 calls, 1 refresh, `ApiUnauthorized`, no loop — OK |
| V-P3 the refresh call itself gets 401 | 1 refresh, no recursion (refresh skips auth), signed out, `signedOut` published — OK |
| V-P4a refresh in flight, the user signs out, the refresh then succeeds | Stays signed out (store too), one `signedOut`, the replay goes out with **no** bearer (`auth_interceptor.dart:48-51`, a path no branch test covers), `ApiUnauthorized` — OK |
| V-P4d sign-out during the first refresh with two waiters | Both `ApiUnauthorized`, 1 refresh — OK |
| **V-P4b / V-P4c / V-P4e** refresh in flight → sign-out → sign-in as another user | **Defect D1** (below) |
| V-P5 no token, 401 | No refresh — OK |
| V-P6a refresh 403 → signs out; V-P6b refresh timeout → keeps the session, `ApiTimeout`; V-P6c refresh 503 → keeps the session, `ApiServer`, 1 refresh (POST not retried); V-P6d 3 concurrent 401s with an offline refresh → 1 refresh, 3 × `ApiOffline`, session kept | All match the TL policy — OK |
| V-P7 a 403 on a normal request | Not refreshed — the behaviour is correct, but no branch test pins it (D2) |
| **V-P8** a `FormData` PUT that gets a 401 | **Defect D3** (below) |

## Mutations ([mutate.py](verifier/mutate.py), [mutations.txt](verifier/mutations.txt); each applied alone, the original targets run uncached, the file restored)
| # | Mutation | Result |
|---|---|---|
| M1 | Shared-refresh latch removed (`await _refresh()`) | KILLED (`auth_interceptor_test`) |
| M2 | Replay keeps the old token (`ours ||` dropped from `onRequest`) | KILLED |
| **M3** | **Refresh on 403 too** | **SURVIVED** → D2 |
| M4 | A failed refresh does not clear the session | KILLED |
| M5 | **Replacement for the engineer's 8th:** `updateTokens` revives a signed-out session (`_Active(current?.userId ?? 'revived', tokens)`, compiles) | KILLED (`session_test` "updateTokens after a sign-out cannot revive the session") |
| M6 | `Session._enqueue` removed | Survived, but **equivalent**: `FileStore` already serialises per key |
| M7 | `_refreshing` never cleared | KILLED |
| M8 | Replay flag ignored | KILLED, but only by a Bazel **TIMEOUT** (60 s, an infinite refresh/replay loop), not by an assertion. The engineer's `mutations.txt` lists it as killed with no failing test shown (D5) |
| M9 | Token counter does not skip revoked numbers | KILLED (`identity_test`, `provider_contract_test`) |
| M10 | Offline refresh signs out | KILLED |
| M11 | Boot never restores (`nothingSaved \|\| true`) | KILLED (`boot_test`, `session_di_test`) |
| M12 | Bearer prefix dropped | KILLED |
| M13 | Sign-out does not delete the store | KILLED |

## Test-integrity audit
- Tests deleted, skipped or weakened: **none**. `git diff origin/main...b40c159` removes no line from any test file. `app_core/boot_test` only gains assertions in the existing root-list test plus one new test (allowed).
- Lint suppressions added: **none**. No `// ignore:`, `skip:` or `solo:` in the diff.
- Golden files updated: none (no UI).
- Every AC has `T-0039-ACn`-named tests: AC1 ✓, AC2 ✓, AC3 ✓, AC4 ✓, AC5 ✓.
- Ownership: the engineer edited only its task file, plus a new F-0038, evidence and check scripts. No STATUS, BOARD, journal or index edits.

## Visual acceptance (UI tasks)
Not a UI task. [`verifier/e2e/01_home_with_restored_session.png`](verifier/e2e/01_home_with_restored_session.png) shows the home page ("Marvel universe", "Config: env=e2e", the Characters and Open placeholder 7 buttons) reached after a boot with a populated store; the probe then asserted the restored session. The committed journey screenshots (01 to 06) show the usual home, list, preview, profile placeholder and deep-link pages, so the app is unchanged by the new initializers.

## Issues found
1. **D1 (major) A refresh result is applied to a different session.** `utility/mc_api_auth/lib/src/auth_interceptor.dart:100-117` (`_refresh`), together with `utility/mc_session/lib/src/session.dart:92-100` (`updateTokens` only checks "signed in", not "same session"). The refresh is not tied to the refresh token or user it started with.
   - **V-P4e:** user A's refresh is answered, but the response arrives after A signs out and B signs in. The session ends up as `userId=u-101` with `accessToken=mc-access-u-100-1`, so B's app makes requests as A. This is a cross-account token mix-up, and it is silent.
   - **V-P4b / V-P4c:** A's refresh is rejected (its token was revoked by the sign-out, or was bad) after B signed in. `_writer.signOut()` signs **B** out and publishes a spurious `SessionChanged(signedOut)`.
   - With the 30 s receive timeout, the window is a slow refresh. Today the window is unreachable in the app (there is no sign-in UI yet), but it becomes reachable with P-044.
   - **Repro:** the `gated` group in `verifier/verifier_probe_test.dart`. An adapter wrapper holds `/v1/auth/refresh` (either the request or the response) while the test calls `api.signOut()` and then `api.signIn(collector@mini-client.test / vault-7)`.
   - **Suggested fix:** capture `_reader.refreshToken` (or a session generation counter) when `_refresh` starts, and apply `updateTokens` / `signOut` only if it is still current. Otherwise treat the outcome as "already changed" and replay. Or give `updateTokens` an `expectedRefreshToken`.
2. **D2 (minor, test gap, but a required mutation) No test pins "no refresh on 403".** The guard is at `auth_interceptor.dart:63`. Mutation M3 (`![401, 403].contains(status)`) passes every test in `utility/mc_api_auth/test/auth_interceptor_test.dart`. The brief lists "refreshing on 403" among the mutations that must turn a test red. The behaviour itself is correct (V-P7). Fix: add a `T-0039-AC2` test where a signed-in request gets 403 and assert 0 refresh calls and 1 request.
3. **D3 (minor) A `FormData` request that gets a 401 can't be replayed.** At `auth_interceptor.dart:91-93`, the replay reuses `options` with the already-finalised `FormData`. The caller gets `ApiUnexpected(StateError: The FormData has already been finalized…)` after a successful refresh (V-P8). `RetryInterceptor` clones `FormData` for exactly this reason (F-0017 item 6). No multipart call exists yet. Fix: clone `FormData` on replay, or skip the replay for one-shot bodies, as the retry interceptor does.
4. **D4 (minor, test gap) The replay-after-sign-out header removal is untested.** `auth_interceptor.dart:48-51` is the only uncovered code in `mc_api_auth` (coverage lines 50-51). V-P4a shows it works. A test like V-P4a would pin it.
5. **D5 (info) M8 is killed only by a 60 s Bazel TIMEOUT.** The suite has no assertion-level guard against a refresh/replay loop, so the failure shows up as a hang. Consider a per-test `timeout:` on the AC2 group. The engineer's `mutations.txt` reports it as killed without showing the failing test.

## Notes for the Tech Lead
- The TL decisions check out as implemented: the failure policy (both branches, V-P6a to d), the mock token shape and rotation with the revoked-skip counter (M9 killed, restart test real), EventBus before Session (no forward dependency), and the boot-read skip (a populated store restores in the real app on the simulator).
- D1 is the blocker. It is a small, local fix in `_refresh`/`updateTokens` plus one test (the V-P4e shape). D2 to D4 are one test each, plus a `FormData` clone.
- Follow-ups the engineer already lists still stand: `FileStore.readSync`, `McTestContainer` registration (F-0024 item 2), `IdentityMockDomain` in `appMockDomains`, and the plan 01 §3.4 order.

## Re-verification at e055107

- **Verifier:** the same Verifier (did not write the code). Narrow scope per ADR-0011: the round-1 defects, the review items listed by the TL, and the gates.
- **Commit verified:** detached HEAD at `e055107` (`ee73ba0` the fix round, `7bf05db` the merge of origin/main). Bazel `/tmp/mc-ob-T-0039-verifier`, shut down at the end. No simulator was needed this round.
- **AC2 as amended on main:** a rejected refresh signs out; a refresh that is unavailable keeps the session; an outcome applies only to the session it started for.
- **Verdict:** **PASS.** Every behaviour on the TL's list is correct, both in the engineer's tests and in my own probes. The round-1 defects D1 to D5 are fixed. Three sub-behaviours are correct but no test pins them; each is caught only by one of my probes (R1 to R3 below). They are minor test gaps, not defects in the code.
- Evidence: [`verifier/reverify-e055107/`](verifier/reverify-e055107/). It holds the gate report, the mutation runner and its results, and my probes with their output and negative controls.

### Gates
| Gate | Result |
|---|---|
| `tool/checks/T-0039-AC5_gates.sh --role verifier` | **PASS** on all 9 gates ([gates.md](verifier/reverify-e055107/gates.md)): 101 tests, lint, arch, rules_fork, format, l10n, closure, fixtures check, coverage |
| Uncached tests: `mc_session`, `mc_api_auth`, `mc_fixtures_identity`, `mc_storage`, `mc_test_utils`, `//app/...` | **26/26** targets pass |
| Coverage, my own parser ([coverage.txt](verifier/reverify-e055107/coverage.txt)) | `mc_session` 92/92 **100 %**, `mc_api_auth` 119/119 **100 %** (round 1's missed lines 50-51 are now covered), `mc_fixtures_identity` 128/130 **98.5 %** |

### Items
Each mutation was run alone, with the original targets uncached ([mutate_r2.py](verifier/reverify-e055107/mutate_r2.py), [mutations_r2.txt](verifier/reverify-e055107/mutations_r2.txt)). My probes are [verifier_probe_test.dart](verifier/reverify-e055107/verifier_probe_test.dart) and [verifier_boot_probe_test.dart](verifier/reverify-e055107/verifier_boot_probe_test.dart). Their output is in [probe_output_r2.txt](verifier/reverify-e055107/probe_output_r2.txt), and the probe-versus-mutation runs are in [probe_controls.txt](verifier/reverify-e055107/probe_controls.txt).

| # | Item | Test(s) | Reverting mutation | My check | Result |
|---|---|---|---|---|---|
| 1 | Epoch compare-and-set | `auth_races_test` "a refresh outcome belongs to the session it started for" (4, including the response-held variant); `session_test` "sessions have epochs" | E1 (`updateTokens` ignores the epoch) **killed**; E2 (`signOut` ignores `ifEpoch`) **killed** | My original `gated` repro now passes. V-P4a stays signed out. V-P4b, V-P4c and V-P4e: B keeps `u-101` with its own tokens and no spurious sign-out. **One refresh per epoch:** V-P9 (A's refresh in flight, B starts its own) passes with 2 refreshes and B refreshed correctly. But E3 (one shared refresh across epochs) **survives the suite** and only V-P9 catches it (R1) | PASS |
| 2 | Cross-account replay | `auth_races_test` "a PUT favourite of user A is not written into B …", "a request retried after B signed in is failed, not sent with B", "a 401 of user A … is not replayed with B" | X1 (the `onRequest` check off) **killed**; X5 and X6 **killed**; X2, X3 and X4 (the `onError` checks off, separately or together) **survive** | The engineer's claim holds only one way. The `onRequest` check (`auth_interceptor.dart:57`) covers the `onError` checks, and it is needed on its own: only it stops a 5xx retry from going out with B's token (X1 killed). The `onError` checks do not cover `onRequest`. The pre-refresh check (`:92-93`) adds nothing beyond the post-refresh one, so it is just an early exit. The post-refresh check (`:114`) **is** needed on its own: without it, A's PUT is replayed *without a bearer* after a sign-out during the refresh, giving 2 PUT calls. My V-P10 catches X3 and X4; the suite doesn't (R2). No cross-account write is possible with any single check removed | PASS |
| 3 | Bodies | "a FormData request … replayed with a copy", "a Stream body … not refreshed or replayed" | B1 (no clone) **killed**; B2 (Stream guard off) **killed** | My round-1 V-P8 now passes | PASS |
| 4 | Transient failures | "only a definite rejection signs out": socket drop, cancel, 429 keep the session; 403 signs out. Plus the round-1 malformed, offline and 5xx tests | T1 (every failure is a rejection) **killed**; T2 (429 counts as a rejection) **killed**; T3 (malformed is not a rejection) **killed** | `_rejects` (`:173-177`) matches the TL list: `ApiUnauthorized`, `ApiMalformed`, and a 4xx other than 408 or 429. My round-1 V-P6a to V-P6d still pass | PASS |
| 5 | Pins | "a 403 on a request is not refreshed"; "T-0039-AC1 a request retried after a sign-out goes out without the old token"; "a replay that gets a 401 again ends after 2 calls and 1 refresh" (`/v1/always-401-capped`) | P1 (403, my old M3) **killed**; P2 (no header strip) **killed**; P3 (retried flag ignored) **killed by an assertion in `auth_races_test`, target time 0.4 s** | The old `auth_interceptor_test` "always-401" test still loops under P3 (TIMEOUT 60 s), but the new capped test fails fast, so the timeout is no longer the only signal | PASS |
| 6 | `FileStore.existsSync` and the key-file check | `file_store_test` "existsSync …"; `session_di_test` "other saved keys alone boot signed out", "a storage path that is a file boots signed out" | S2 (always read) **killed** (`boot_test` 0.7 s, `mc_test_utils` hang). **S1 (back to the directory listing) survives the suite** | My probe uses a `FileStore` spy that counts asynchronous `read` calls. V-B1: a directory holding `search_history` plus a stray file causes **no** read at boot. V-B2: a saved session causes exactly one read and is restored. V-B3: an empty directory causes no read. V-B4: a corrupt session file is read, comes back signed out, and heals. **V-B1 fails under S1**, so the probe tells the two paths apart; the existing test only checks the resulting state (R3) | PASS |
| 7 | Repeat sign-in | `session_test` "a repeat sign-in of the same user announces nothing, another user does" | R1 (always announce) **killed**; R2 (announce only from signed out) **killed** | The epoch still changes on a repeat sign-in, so in-flight work for the old tokens is dropped, which is correct | PASS |
| 8 | `McTestContainer` session and auth | `auth_container_test` (sign in inside `runAsync`, then `/v1/me` returns `Rhea Reader`, interceptor last; the next test starts signed out with a 401) | C1 (no `ApiAuthDIInitializer`) **killed**; C2 (no Session or ApiAuth) **killed** | `isolation_test` 6 → 8 is correct: the old list had config, monitoring, storage, backend, client, bus; the new one has config, monitoring, storage, **bus, session**, backend, client, **auth**. It is the same exact-equality assertion with the new count, not a loosening. It is the only removed test line in `ee73ba0` | PASS |
| 9 | Lazy save queue | `auth_container_test` (sign-in in `tester.runAsync` after a fake-async boot) | L1 (`_tail` created eagerly at construction) **killed**: the sign-in hangs until the test's 50 s budget | The comment at `session.dart:62-65` matches the behaviour | PASS |
| 10 | Gates | see above | — | — | PASS |

### Remaining findings (minor, test gaps only; the behaviour is correct)
- **R1:** no test pins "one refresh per epoch" (`auth_interceptor.dart:137-152`). Mutation E3 survives. Lifting my V-P9 into `auth_races_test` would pin it.
- **R2:** no test pins the post-refresh epoch check (`auth_interceptor.dart:114-117`). Mutations X3 and X4 survive. Without the check, A's request is replayed anonymously after a sign-out during its refresh. Lifting my V-P10 would pin it. The pre-refresh check (`:92-93`) adds nothing beyond `:114`.
- **R3:** `session_di_test` "other saved keys alone boot signed out" cannot tell the skip path from the read path, so mutation S1 survives. A read-counting spy like my V-B1 would pin it.
- **Info:** my round-1 probe "V-AC1 sign-in as B during a retry backoff: the retry carries B" now fails **by design**. Under the amended AC2 that retry is rejected as `ApiUnauthorized`, and `auth_races_test` covers exactly that. Under P3 the old `auth_interceptor_test` "always-401" test still times out, which is harmless now that the capped test fails fast.

### Integrity
- `git diff b40c159 ee73ba0 -- '*_test.dart'` removes exactly one line: the `isolation_test` count, 6 → 8, which is correct.
- No `// ignore:`, `skip:` or `solo:` lines were added by T-0039. The only new suppression in the merged diff is `// ignore_for_file: avoid_print`, which arrives through the origin/main merge, outside T-0039.
- No golden changes from T-0039. The `characters_list` and `mc_ds_navigation` goldens come from the merged T-0040.
- Every new test is named `T-0039-ACn`.
- My probes ran as temporary Bazel targets in my worktree and were removed afterwards. The tree is clean apart from this evidence.
