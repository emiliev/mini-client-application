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
