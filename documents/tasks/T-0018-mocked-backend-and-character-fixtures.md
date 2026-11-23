# T-0018: `mc_mocked_backend` engine + `mc_fixtures_characters` / `mc_fixtures_media` (P1-06, P1-07)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0018-mocked-backend` (from `origin/main` `53c612d`+) |
| Created | 2026-11-23 |
| Depends on | T-0014 (toolchain, merged) |
| Related | [plan 01 §5, P1-06, P1-07](../plan/01-architecture-and-modules.md), ADR-0005, D5, R3, F-0003 |

## Goal
The data source for the whole Marvel app: a deterministic, data-free Dio `HttpClientAdapter` engine, plus the first fixture packages (characters, and media for images), so features can run their real retrofit APIs against realistic paginated data.

## Scope
- **In:**
  - `utility/mc_mocked_backend`: engine, route registry, seeded latency profiles (`none` / `realistic`), `FailureRule` injection, traffic diagnostics, 404 for unknown routes.
  - `utility/mc_fixtures_characters`: about 1,500 deterministic characters (original names and text; no copyrighted Marvel art), handlers for pagination, `nameStartsWith` search and detail, a route manifest, `CONTRACT.md`, and provider contract snapshots.
  - `utility/mc_fixtures_media`: bundled placeholder images, plus `ApiImage` path and variant resolution.
  - `BUILD.bazel` for each package. Add the packages to the root `pubspec.yaml` `workspace:` list (that's the only root-file change; the TL re-resolves the lock at merge).
- **Out:** `mc_api_client` / `mc_api_errors` (P1-05), features.
- **Files / areas:** `utility/mc_mocked_backend/`, `utility/mc_fixtures_characters/`, `utility/mc_fixtures_media/`, plus one root `pubspec.yaml` hunk.

## Acceptance criteria
- **T-0018-AC1:** Given seed 42, when one request sequence runs on two backend instances, then the responses are byte-identical.
- **T-0018-AC2:** Given latency `none` under `fake_async`, then requests complete without advancing time. Given `realistic`, then the delay equals the seeded value.
- **T-0018-AC3:** Given `FailureRule(GET /v1/x, timeout, once)`, then call 1 throws `connectionTimeout` and call 2 succeeds.
- **T-0018-AC4:** Given an unregistered route, then the response is 404 with a body naming the path.
- **T-0018-AC5:** Given traffic logging, then the diagnostics stream emits method, path, status and duration.
- **T-0018-AC6:** Given `GET /v1/characters?offset=30&limit=30`, then page 2 of 1,500 comes back in stable order. Given `nameStartsWith=spi`, then every name starts with "spi", case-insensitive.
- **T-0018-AC7:** Given the provider contract snapshots, then the responses match them. Given any `ApiImage` in a response, when resolved, then the bundled asset exists.
- **T-0018-AC8:** `tool/bazelw test //utility/mc_mocked_backend/... //utility/mc_fixtures_characters/... //utility/mc_fixtures_media/...` passes, and `build --config=lint` is clean.

## Log
- 2026-11-23: Created and dispatched (app work, in parallel with T-0017).

## Outcome
_Pending._
