# T-0050: `mc_api_auth` pins a request to its session epoch from the first send (P-083, P-080, P-089, P-093)

| Field | Value |
|---|---|
| Status | In Progress |
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
