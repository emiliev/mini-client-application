# T-0050: `mc_api_auth` pins a request to its session epoch from the first send (P-083, P-080, P-089, P-093)

| Field | Value |
|---|---|
| Status | In Verification |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Opus tier** (auth / security; ADR-0011) |
| Branch | `fleet/T-0050-auth-first-send-pin` |
| Created | 2026-11-27 |
| Depends on | T-0039 (`mc_api_auth`, `mc_session` epoch), T-0041, T-0048 (callers with auth-gated writes) |
| Related | P-083 (reproduced by the T-0048 Verifier: Dio runs each request interceptor in a new event-loop turn, so a user switch in that window gives a first send the new user's bearer); P-080 (three auth pins); P-089 (double tap in `comics_details`); P-093 (T-0048 test gaps); F-0038, F-0040, F-0048 |

## Goal
A write that a feature started for user A must never go out, on its first send or any retry, with user B's bearer. The fix belongs in the kit, so every feature and brick gets it for free.

## Decision (TL)
- **`mc_api_auth`:**
  - A caller can pin a request to the session epoch it saw, for example `Options(extra: {mcSessionEpoch: epoch})`, set through a small helper such as `authPinned(epoch)`.
  - In `onRequest`, a pinned request whose epoch is no longer current is rejected **before any bearer is attached**. It is rejected with `ApiFailure.unauthorized`, or a dedicated `ApiSessionChanged` failure if that's cleaner; document which.
  - Unpinned requests keep today's behaviour.
- **Callers:** `comics_details`' favourite write and `library_reading_list_editor`'s writes (POST, both PUTs, DELETE if any) pin their epoch. Their bloc-side epoch checks stay as defence in depth.
- **Also in this task (small, related):**
  - **P-080:** pin the three untested `mc_api_auth`/`mc_session` behaviours. The Verifier's probes are in `documents/evidence/T-0039/verifier/reverify-e055107/`.
  - **P-089:** a double tap in one frame calls `comics_details`' navigator twice. Add the same 500 ms open guard as `discovery_search`, pinned from both sides.
  - **P-093:** T-0048's test gaps (the pre-write checks, the sign-in gate's session check, the double-Retry load guard, the after-close guard in the session listener, the description and `too_many_comics` error mappings, the two `mc_forms` tests, `en_XA` on not-found and failed-load, the German duplicate-name scenario).

## Acceptance criteria
- **T-0050-AC1:** The kit check: given a pinned request and a session change before it is sent, then no request reaches the backend and the caller gets the documented failure. Test this with the T-0048 Verifier's timing, a synchronous user switch right after the call, through real Dio and the mocked backend. Unpinned requests are unchanged, and all T-0039 tests stay green.
- **T-0050-AC2:** In each caller, the race scenarios that reproduced the bug send **no** request for the wrong user and assert it on the backend's traffic:
  - `comics_details`: tap favourite, then switch to another user;
  - `library_reading_list_editor`: Create, then switch, and an edit's two writes, then switch between them.
- **T-0050-AC3:** P-080, P-089 and P-093 are closed. Each item has a test that fails without it and a mutation, whether it's pinning an existing behaviour or a fix.
- **T-0050-AC4:** Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and coverage ≥ 90 % for every touched package. Byte identity and cutoff hold for both features, and the mini_client e2e passes.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Sonnet). Branch from `origin/main` (06baf2d). The AC1 test and the helper came first, with no guard: 4 of 10 tests failed, the pinned PUT left under u-101's bearer ([log](../evidence/T-0050/engineer/AC1_before_fix.log)). Then the guard, the callers, the P-080, P-089 and P-093 tests, the gates, the e2e and the mutation run.
- 2026-11-27: Decisions inside the TL's brief: the failure is `ApiFailure.unauthorized('The session changed')` (no new type, F-0050 section 2); the epoch the callers pin is the one checked right before the write (`_session.epoch` in the favourite bloc, the bloc's `_epoch` in the editor); only writes are pinned; the P-093 bloc guards are pinned in a new `bloc_guards_test` that runs the real bloc over a `Dio` with no auth interceptor (otherwise the pin hides them).

## Outcome
**Handed off** for review and verification on `fleet/T-0050-auth-first-send-pin`. Finding: [F-0050](../findings/F-0050-auth-first-send-pin.md). Evidence: [`documents/evidence/T-0050/engineer/`](../evidence/T-0050/engineer/).

### What was built
- **`utility/mc_api_auth` (AC1):** `authPinned(epoch)` and `mcSessionEpoch` (`src/auth_pin.dart`, exported). `AuthInterceptor.onRequest` rejects a request whose pinned epoch is not the current one **before any bearer is attached**, whether or not someone is signed in, with `ApiFailure.unauthorized('The session changed')` (the failure a retry across a session change already gets). Requests without a pin and `skipAuthKey` requests are unchanged. The class doc says so.
- **`feature/comics/comics_details` (AC2, AC3):**
  - `putFavourite` and `deleteFavourite` take `@Extras() Map<String, dynamic> extras`; `ComicsDetailsRepository.setFavourite` takes `required int epoch` and passes `authPinned(epoch)`; `ComicFavouriteBloc` passes `_session.epoch`. `mc_api_auth` moved from a test dependency to a runtime one (pubspec, BUILD).
  - P-089: `ComicDetailsBloc` ignores a second character or creator hand-over within `openGuard` (500 ms, as `discovery_search`), one guard for both, cancelled in `close()`.
- **`feature/library/library_reading_list_editor` (AC2, AC3):** `createList`, `updateList`, `replaceItems` take `extras`; the repository's three writes take `required int epoch`; the bloc passes the epoch it checks with `_canWrite`. `mc_api_auth` is a runtime dependency.
- **`mc_test_steps` (generic):** `{user} signs in just before the app sends {route}` (a hook at the front of the root `Dio`: the session switches in memory the moment the first matching request enters the chain, which is the P-083 window made deterministic) and `the session belongs to {user}`. `dio` is a new dependency of the package.
- **Not touched:** `app/` (T-0049's), `mc_session` and `mc_forms` lib code, the T-0039 tests (all green, none changed).

### AC to evidence
| AC | Tests and evidence |
|---|---|
| AC1 | `mc_api_auth:auth_pin_test` (10 tests): a user switch in the same turn as the call (the Verifier's timing) sends no request and answers `ApiUnauthorized`; a sign-out likewise; the message; a pin of the current session gets the bearer; a pin of a signed-out epoch is rejected after a sign-in; a `skipAuthKey` request ignores the pin; a pinned 401 is refreshed and replayed once; an unpinned request is unchanged; the key. All run through real Dio, the real session and the mocked backend, and assert on `backend.recentTraffic`. **Before the guard 4 of 10 fail** ([AC1_before_fix.md](../evidence/T-0050/engineer/AC1_before_fix.md), [log](../evidence/T-0050/engineer/AC1_before_fix.log)). All T-0039 tests (`auth_interceptor_test`, `auth_api_test`, `auth_races_test`, `session_*`) are unchanged and green |
| AC2 | `comics_details:bdd_test` "A user switch right before the favourite is sent / removed sends nothing for the wrong user" (0 PUT, 0 DELETE, no announcement, the session is the collector's, neither user has the favourite, or both still do). `library_reading_list_editor:bdd_test` "Another user signing in right before the POST is sent writes nothing for them" (0 POST, collector still has 1 list, reader 3, no announcement), "... right before the second write of an edit sends it for no one" (1 PUT with the reader's token, 0 `/items`), "... right before the first write of an edit sends nothing". `:contract_test` "every write of the repository is pinned to the epoch it is given, and no read is". Without the pins the comics and library scenarios fail (mutations C1 to C5) |
| AC3, P-080 | `auth_races_test` "one refresh per session: user A is in flight, user B starts its own" (V-P9), "a PUT of user A after a local sign-out during the refresh is not replayed without a token" (V-P10); `session_di_test` "with no session file nothing is read at boot, whatever else is in the directory" (V-B1, a read-counting spy) and "a saved session is read once and restored" |
| AC3, P-089 | `comics_details:bdd_test`: a double tap on a character, a second tap at 499 ms (same tap), a tap at 501 ms (opens again), a double tap on a creator |
| AC3, P-093 | `:bloc_guards_test`: V01 and V02 (the create's and the details write's pre-write check), V03 (the check between the two writes, with a 100 ms answer), V19 (the sign-in gate), V20 (double Retry), V23 (a session event reaching a closing bloc), V21 and V22 (the form's mappings). `mc_forms:form_controller_test` "reset forgets the server errors: a later edit of another field does not bring one back"; `wizard_controller_test` "reject for a field on another step does not move the wizard while completing". `:bdd_test` l10n: German "refusal of a name", `en_XA` not-found and failed-load at 1x and 2x |
| AC4 | [T-0050-AC4_gates.md](../evidence/T-0050/engineer/T-0050-AC4_gates.md): `test //...` (146 tests), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures check, relative paths, byte identity, cutoff, not committed and gen-l10n parity for **both** features (T-0041-AC7_* and T-0048-AC7_*), coverage (`mc_api_auth` 100 %, `mc_session` 100 %, `mc_forms` 100 %, `comics_details` 100 %, `library_reading_list_editor` 98.8 %). e2e: [9 of 9 PASS](../evidence/T-0050/engineer/mini_client/e2e-summary.md) on `mc-T-0050-engineer-30943` (deleted), including the comics and reading-list journeys |

### Mutations
[mutations.sh](../evidence/T-0050/engineer/mutations.sh) and [mutations.log](../evidence/T-0050/engineer/mutations.log) (`MC_TASK=T-0050 MC_ROLE=engineer`): 35 mutations, one per guard and per gap: the kit (K1 to K7), P-080 (3), the callers' pins (C1 to C5, H1), P-089 (5), P-093 (V01, V02, V03, V19, V20-a, V21, V22, V23, F1, F2, E1, E2, DE). One mutation, **V20-b, is equivalent and must survive**: `_loading` alone is redundant with the `state is _LoadFailed` check in front of it (F-0050 section 4); removing both is killed (V20-a). Three first attempts survived (V03, V23, F1) because the test did not reach the guard; the tests were fixed, not the mutations argued away (F-0050 section 3).

### Test integrity
- No test deleted, skipped or weakened; no `// ignore:`; no golden changed. The existing steps `I tap the cast member` and `I tap the creator` were rewritten onto one helper (same behaviour, same scenarios green).
- The contract test's six repository calls gained `epoch: 0`, because the repository's write signature changed. They run without an auth interceptor, so the pin has no effect there.
- New dependencies: `mc_api_auth` (runtime) for both features; `mc_storage` (dev) for `library_reading_list_editor`; `dio` for `mc_test_steps`.
- New file outside the task's list: `tool/checks/T-0050-AC4_gates.sh` (the gates, as every task adds one).

### Decisions needed
- None blocking. For the TL: the favourite bloc pins `_session.epoch` (read when the write starts). A stale shown state (a session change the bloc has not yet heard of) is not caught by the pin; the bloc's own reload covers it, as before. If you want the pin to be the *shown* epoch, a bloc-level test harness for `comics_details` is needed first, because no feature test can reach that order of events.
- Coverage of `utility/mc_test_steps` is not gated (test-only step code, as in T-0048).

### Follow-ups
- P-083, P-080, P-089 (comics_details part) and P-093 are closed by this task. The other P-089 half ("the SC/SR/LD bricks") stays with P1-24.
