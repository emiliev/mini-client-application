# T-0026: `mc_test_utils` harness (P5-01)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-24; Verifier PASS `29360b8`) |
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
- 2026-11-24: Engineer implemented `utility/mc_test_utils` and moved the golden helpers from `mc_ds_testing` (now a re-export shim). Gates green: `bazel test //...` (43/43), `build --config=lint //...`, `mc_arch_check`. Evidence in `documents/evidence/T-0026/engineer/`.

## Outcome
Status: ready for the Verifier.

**AC to test map** (all in `utility/mc_test_utils/test/`):
- AC1: `harness_test.dart` "T-0026-AC1 an endpoint with no fixture set fails by route" (unmatched route named, also when the body throws first) and "T-0026-AC1 session is unavailable outside mcTestWidgets".
- AC2: `isolation_test.dart` "T-0026-AC2 isolation, first" / "second" (both assert a fresh DI container, backend, platform, surface and session, then dirty them; run under `--test_arg=--test-randomize-ordering-seed=<n>` for 6 seeds).
- AC3: `harness_test.dart` "T-0026-AC3 fail(times: 1) fails once, the retry succeeds" and "T-0026-AC3 hold keeps loading observable until release".
- AC4: `init_flow_test.dart` "T-0026-AC4 initFlow gives the DS theme, en and iOS"; `golden_test.dart` "T-0026-AC4 probe golden ..." (moved helpers, 8 goldens); exports and coverage below.

**Coverage:** 97.8 % (272/278 lines), `documents/evidence/T-0026/engineer/coverage.txt`.

**Root changes:** `pubspec.yaml` gets `utility/mc_test_utils`. No lock change. `mc_ds_testing` becomes a re-export shim (BUILD, pubspec, lib).

**Findings:** F-0024 (MockMonitoring without mocktail, the root list is duplicated because of layering, zero retry delay, strictness in the adapter wrapper).

**Review round (2026-11-24, after Verifier PASS and `/code-review`):** fixed (each with an AC-named test in `harness_test.dart` / `isolation_test.dart`): untyped `ExternalDouble` (rejected with the type to write) and externals that duplicate a root type (rejected); fixture-set scenarios now registered (`MockBackend.addDomain`, small `mc_mocked_backend` change, TL-approved); malformed URLs forwarded (400); `fail` on an unrouted path no longer unmatched; held requests honour cancellation. Nits: `containerInitialized` set after a successful init, session built before any global is touched, body stack trace kept, `tearDownAll` safe on subset runs, per-package `analysis_options.yaml` dropped (F-0021), finding renumbered F-0022 to F-0024. Gates re-run green (43/43, lint, arch_check); coverage 97.7 % (300/307); isolation test passes under seeds 11, 222, 3333.

**Follow-ups:** (1) drift-guard test in `app_core` comparing its root list with `McTestContainer.initializers`; (2) migrate the `mc_ds_*` golden tests to `mc_test_utils` and delete the `mc_ds_testing` shim; (3) `expectScreenGolden`, `GoldenDevice`, `expectIosAccessibility` and `servedStrings` from plan 05 §1.2 are not built (not in this task's scope); (4) `@isTest` annotation needs `meta`.

## Merge (TL)
- 2026-11-24: Verifier PASS `5762cd7` (97.8 % coverage; isolation across 7 seeds). `/code-review` found 5 important harness bugs (untyped externals, fixture-set scenarios, malformed URLs, `fail()` on unrouted paths, held-request cancellation), fixed in `608796a`; the TL approved `MockBackend.addDomain`. Re-verify PASS `29360b8` (14/14 probes). The TL merged `--no-ff`; on the merge result tests passed 47/47, lint was clean and `mc_arch_check` reported OK.
- Follow-ups: P-049 (strengthen the held-cancel test to assert the backend is never hit after release; correct F-0024 #13 on `%FF` giving 404 vs 400; add an `addDomain` unit test; the `app_core` drift guard for the `McTestContainer` root list; migrate the DS goldens off the `mc_ds_testing` shim).
