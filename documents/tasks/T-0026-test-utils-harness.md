# T-0026: `mc_test_utils` harness (P5-01)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0026-test-utils` |
| Created | 2026-11-24 |
| Depends on | T-0017 to T-0023 (foundation) |
| Related | [plan 05 §2, §3, §5, P5-01](../plan/05-testing-and-bdd.md), Tide's `test_utils` ([research](../research/tide-miniclient/app-navigation-testing.md) §4.4), ADR-0010, P-033 (absorb `mc_ds_testing`) |

## Goal
Tide's `test_utils` for our stack. Sociable feature tests enter through the flow, double only external dependencies and the backend (at the transport layer, via `mc_mocked_backend`), and start from a fresh environment for every test.

## Scope
- **In:**
  - `utility/mc_test_utils` (`testonly`): `mcTestWidgets` (a test wrapper with a per-test reset), `McBackendHarness` (fixture sets, `fail(route, kind, times)`, `hold` / `release`, unmatched-request failure), `McTestContainer` (composes the production root initializers), `MockMonitoring`, and `initFlow` (pumps a `FeatureFlow` with the DS theme, locale `en` and the iOS platform).
  - Absorb the `mc_ds_testing` golden helpers, re-exported (P-033).
- **Out:** `mc_test_steps` (P5-02), BDD generation (P3-05).

## Acceptance criteria
- **T-0026-AC1:** Given a flow that calls an endpoint with no fixture set, when it runs under `mcTestWidgets`, then the test fails with `Unmatched request GET /v1/…` naming the route.
- **T-0026-AC2:** Given two tests in one aggregated target, where the first registers externals, fixtures and a text scale, when the second runs (also under a random ordering seed), then it sees a fresh DI container, backend, platform and surface.
- **T-0026-AC3:** Given `fail(route, serverError, times: 1)` and `hold` / `release`, then the first request fails, the retry succeeds, and the loading state is observable without timers.
- **T-0026-AC4:** Given `initFlow`, then inside the flow `Theme.of` is the DS theme, the locale is `en` and `defaultTargetPlatform` is iOS. `MockMonitoring` and `McTestContainer` are exported, and package coverage is ≥ 90 %.

## Log
- 2026-11-24: Created and dispatched.

## Outcome
_Pending._
