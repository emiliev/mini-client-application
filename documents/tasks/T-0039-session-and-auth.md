# T-0039: Auth slice: `mc_session`, `mc_api_auth`, `mc_fixtures_identity` (P1-05 AC2, P1-08 subset)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-26 `4be9f83`; Verifier PASS `807cad3`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0039-session-and-auth` |
| Created | 2026-11-26 |
| Depends on | T-0020 (`mc_storage`, `mc_event_bus`), T-0023 (`mc_api_client`), T-0018 (`mc_mocked_backend`) |
| Related | plan 01 U08, U17, D-09, P1-05 AC2, P1-08, P1-16 AC4 (auth redirect, P-044), R29 |

## Goal
Signed-in state for the app. The SC exemplar's favourite needs `requestSignIn()`, and the app's `redirect` guard needs a session. It's all mocked: no real identity provider.

## Scope
- **In:**
  - `utility/mc_session` (U08): `SessionReader` / `SessionWriter`, a token store on `mc_storage`, an auth-state stream, and `SessionChanged` on `mc_event_bus`. It's pure Dart, and an injectable DI initializer registers it.
  - `utility/mc_api_auth` (U17): a Dio interceptor. It adds the bearer token, and on a 401 makes exactly one refresh attempt then retries; if the refresh fails, it forces sign-out. Concurrent 401s share one refresh.
  - `utility/mc_fixtures_identity`: `POST /v1/auth/sign-in` (fixture users), `POST /v1/auth/refresh`, `POST /v1/auth/sign-out`, `GET /v1/me`, and the `GET/PUT/DELETE /v1/me/favourites/{kind}/{id}` writes. Writes persist until `reset()` (P1-08 AC4). The `default`, `empty` and `server_error` sets exist, plus an `expired_token` scenario.
  - Register `SessionDIInitializer` and `ApiAuthDIInitializer` in `app_core` root initializers in plan 01 §3.4 order. Only register them; don't add sign-in UI.
- **Out:**
  - The sign-in feature UI and the router `redirect` guard (P-044); those come in a later task.

## Acceptance criteria
- **T-0039-AC1:** Given a signed-in session, then requests carry `Authorization: Bearer <token>`. Signed out, they carry no header.
- **T-0039-AC2:** Given an expired token, then exactly one refresh is attempted and the request is retried once with the new token. Given 3 concurrent requests that all get a 401, then exactly one refresh happens. Given a refresh that is **rejected** (401, a 4xx `invalid_refresh_token`, or a malformed answer), then the session is cleared, `SessionChanged(signedOut)` is published, and the original request fails with `ApiFailure.unauthorized`. Given a refresh that is **unavailable** (offline, timeout, 5xx, 429, a transport error), then the session is kept and that failure is passed through. A refresh outcome only applies to the session it started for. _(Amended by the TL, 2026-11-26.)_
- **T-0039-AC3:** The identity fixtures: sign-in with a fixture user returns tokens, and a wrong password returns 401. A favourites write persists across requests until `reset()`. Determinism holds as in P1-06 AC1.
- **T-0039-AC4:** The session survives a new `mc_session` instance on the same store. A corrupt store reads as signed out and heals on the next write (as T-0030's `SearchHistory`).
- **T-0039-AC5:** All three packages are pure Dart, registered, at ≥ 90 % coverage, and pass the fixtures check. The app still boots: `app_core` boot tests and `mini_client` tests pass. Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format.

## Log
- 2026-11-26: Created and dispatched (TL).
- 2026-11-26: Engineer built the three packages, registered them in `app_core` (order: Config, Monitoring, Storage, EventBus, Session, MockedBackend, ApiClient, ApiAuth), merged `origin/main` (T-0038; only the workspace list conflicted, locks unchanged). Gates PASS, evidence in `documents/evidence/T-0039/engineer/`.

## Outcome
- **Packages:** `utility/mc_session` (reader/writer ports, `Session` on `FileStore`, `SessionChanged`, DI), `utility/mc_api_auth` (`AuthInterceptor`, `AuthApi` with sign-in, sign-out, refresh, DI), `utility/mc_fixtures_identity` (7 routes, 2 users, sets `identity.default/empty/server_error`, scenarios `identity.expired_token` and `identity.server_error`, CONTRACT.md, 11 snapshots).
- **AC map:** AC1 `auth_interceptor_test` / `auth_api_test` ("T-0039-AC1 ..."); AC2 `auth_interceptor_test` ("T-0039-AC2 ...": real concurrent Dio requests on the mocked backend, one refresh for 3 concurrent 401s, failed refresh clears session and publishes `SessionChanged(signedOut)`); AC3 `identity_test`, `provider_contract_test`; AC4 `session_test`, `session_di_test`; AC5 `no_flutter_test` x3, `session_di_test`, `auth_api_test` (registration), `app_core:boot_test`, and `tool/checks/T-0039-AC5_gates.sh` / `_closure.sh`.
- **Gates:** `documents/evidence/T-0039/engineer/gates.md` PASS: test //... (97 pass), lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, closure (pure Dart, positive control), fixtures check, coverage 100 % / 97.9 % / 98.5 %.
- **Mutations:** `mutations.txt`: 7 of 8 killed by tests (the 8th, "updateTokens revives", was killed by a compile error from dead code, so it is not evidence).
- **Decisions for the TL:** refresh failure policy (server rejection signs out; offline/timeout/5xx keeps the session), root order (EventBus before Session), mock refresh tokens rotate, `SessionDIInitializer` skips the read for an empty storage directory. See [F-0038](../findings/F-0038-session-and-bearer-refresh-design.md).
- **Test integrity:** no tests deleted, skipped or weakened; no `// ignore:`. `app_core/boot_test` gained assertions plus one new test.
- **Follow-ups:** `FileStore.readSync`; add session and api auth to `McTestContainer`; add `IdentityMockDomain` to `appMockDomains` with the sign-in UI; plan 01 §3.4 order.

### Fix round (Verifier FAIL on AC2, review)
Items: (1) epoch compare-and-set for refresh outcomes (`SessionReader.epoch`, `updateTokens(epoch:)`, `signOut(ifEpoch:)`), Verifier probes V-P4a/b/c/e committed in `auth_races_test.dart`; (2) no cross-account replay or retry (PUT favourite test); (3) `FormData` cloned, `Stream` never replayed; (4) only a definite rejection signs out (unexpected, cancel, 429 keep the session); (5) 403 pinned; (6) sign-out token strip pinned; (7) loop guard fails on an assertion (capped route), not the 60 s timeout; (8) `SessionDIInitializer` checks the session's own file (`FileStore.existsSync`, added to `mc_storage`, approved); (9) repeat sign-in of the same user is not re-announced; (10) `McTestContainer` registers EventBus, Session, ApiAuth (isolation_test's initializer count assertion 6 to 8, disclosed). Also fixed: `Session`'s save queue is created lazily (F-0038 fact 14). Mutations: `mutations_round2.txt`; two single mutations of the replay guards survive because `onRequest` and `onError` both guard (defence in depth); removing the `onRequest` one as well is killed.

## Merge (TL)
- 2026-11-26: Verifier (Opus) FAIL `fb5332c` on AC2: a refresh outcome could be applied to a different user's session. `/code-review` added cross-account replay, FormData/Stream replays and transient errors signing users out. TL decisions: AC2 amended (rejected → sign out; unavailable → keep; outcomes apply only to the session they started for). Fix round `e055107`: a session epoch with compare-and-set, epoch-checked replays, a FormData clone and no Stream replay, a narrow sign-out rule, pins, `FileStore.existsSync`, a lazy save queue, and `McTestContainer` with session and auth. Re-verify (Opus, narrow, under ADR-0011) PASS `807cad3`. The TL merged `--no-ff`; on the merge result `check` passed, 101/101 tests, lint was clean, `mc_arch_check` reported OK, the fixtures check passed and the sim app built.
- Follow-up: P-080 (pin three behaviours that are correct but unpinned, using the Verifier's ready probes).
