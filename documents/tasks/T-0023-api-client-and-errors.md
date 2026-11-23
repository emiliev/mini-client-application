# T-0023: `mc_api_errors` + `mc_api_client` (P1-05 subset)

| Field | Value |
|---|---|
| Status | In Review |
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
Implemented by the Engineer; gates pass (`test //...` 31/31, lint, `mc_arch_check`). Evidence: `documents/evidence/T-0023/engineer/`. Finding: F-0017.

| AC | Test |
|---|---|
| AC1 | `mc_api_client:api_client_test` "T-0023-AC1: ..." (six, through `mc_mocked_backend` failure rules); `mc_api_errors:api_failure_test` (direct mapping) |
| AC2 | `api_client_test` "T-0023-AC2: ..." (503 GET = 3 attempts; recovery on 3rd; POST once; 404 not retried; one log per attempt) |
| AC3 | `api_failure_test` "T-0023-AC3: ..." |
| AC4 | `api_client_test` "T-0023-AC4: ..." |
| AC5 | the gates above plus `no_flutter_test` in both packages ("T-0023-AC5") |

Review fixes (2nd commit):
- Retry: FormData cloned per attempt, stream bodies and receive timeouts not retried, backoff raced against `CancelToken` (AC2 tests "request bodies and cancellation").
- `ApiClientError(status)` for other 4xx (AC1 tests in both packages).
- `AppConfig.apiBaseUrl` added (`mc_config`, `tool/bazel/config/*.json`, `app_config_test`); `ApiClientDIInitializer` reads it, with an `baseUrl` override (AC4 tests). Monitoring is resolved per request; a missing one fails the request (AC4 test).
- `dio: ^5.11.0`; `ApiUnexpected` message format `Type: message`; `mc_mocked_backend` made pure Dart with `dart_test`.

Verifier FAIL fixes (3rd commit):
- AC5: `cycle_breaks = {"dio": ["dio_web_adapter"]}` in `MODULE.bazel` (TL-approved; F-0019). `tool/checks/T-0023-AC5_flutter_free.sh` runs `cquery 'deps(...)'` for both packages and fails on Flutter markers or on `mc_mocked_backend` in the closure (negative control: it fails without the `MODULE.bazel` line). Report: `documents/evidence/T-0023/engineer/AC5_flutter_free.md`.
- Dependency direction: `ApiClientDIInitializer` takes an `HttpClientAdapter`; `mc_mocked_backend` is a dev/test dependency of `mc_api_client` only. `app_core` (T-0021) passes `MockBackend.adapter`.

Decisions and gaps:
- The app builds the `MockBackend` from `AppConfig` and passes its adapter.
- `mc_fixtures_characters` still uses `flutter_test` and `dio: ^5.9.0` (follow-up).
- No tests were deleted, skipped or weakened (mocked_backend tests only changed their test import); no `ignore:` added.
