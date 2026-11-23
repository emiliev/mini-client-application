# T-0023: `mc_api_errors` + `mc_api_client` (P1-05 subset)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0023-api-client` |
| Created | 2026-11-23 |
| Depends on | T-0017 (`mc_prelude`, `mc_di`), T-0018 (`mc_mocked_backend`), T-0020 (`mc_config`, `mc_monitoring`) |
| Related | [plan 01 §5, P1-05](../plan/01-architecture-and-modules.md), Tide's `api_client` ([research](../research/tide-miniclient/architecture-core.md) §4.4), D5, ADR-0005 |

## Goal
Tide's `api_client` utility: the shared Dio instance that every feature's retrofit API uses, wired to `mc_mocked_backend` as its `HttpClientAdapter`, plus a typed failure model.

## Scope
- **In:**
  - `utility/mc_api_errors`: `ApiFailure` (timeout, offline, unauthorized, notFound, server, malformed, unexpected), `ApiFailure.from(Object)`.
  - `utility/mc_api_client`: the Dio factory (base URL from `mc_config`, timeouts, logging to `mc_monitoring`, retry policy for idempotent requests), `McDIInitializer` registering the Dio instance with `mc_mocked_backend`'s adapter, and a `Result`-returning call helper.
- **Out:** `mc_api_auth`, `mc_session`, `mc_analytics`, `mc_feature_flags`, `mc_cache`, `mc_offline` (later P1-05 tasks).

## Acceptance criteria
- **T-0023-AC1:** Given each Dio failure (timeout, offline, 401, 404, 500, malformed), then it maps to the matching `ApiFailure`. Exercise it through `mc_mocked_backend` failure rules.
- **T-0023-AC2:** Given GET 503 with retry 2, then 3 attempts are made. A POST is never retried.
- **T-0023-AC3:** Given `ApiFailure.from` over a non-Dio throwable (a `TypeError` from a bad JSON shape), then it is `ApiFailure.unexpected` with the message kept.
- **T-0023-AC4:** Given the DI initializer, then `diContainer<Dio>()` returns one shared instance whose adapter is the mocked backend, and a request to `/v1/characters` returns page 1.
- **T-0023-AC5:** `test //...`, lint and `mc_arch_check` pass. Both packages are Flutter-free (R15).

## Log
- 2026-11-23: Created.

## Outcome
_Pending._
