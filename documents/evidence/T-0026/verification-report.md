# Verification report: T-0026, `mc_test_utils` harness (P5-01)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:**
  - Round 1: `fleet/T-0026-test-utils` @ `033d4c9`, on `fleet/T-0026-verify`.
  - **Round 2 (review fixes): `608796a`**, on `fleet/T-0026-verify2`. See [Round 2](#round-2-review-fixes-at-608796a) at the end. Rounds 1 and 2 have the same AC-to-test map.
- **Simulator:** none. This is a host-only utility task with no e2e.
- **Output base:** `/tmp/mc-ob-T-0026-verifier` (shut down at the end)
- **Verdict:** **PASS** (round 1 at `033d4c9`; round 2 at `608796a`)

The sections up to "Notes for the Tech Lead" are the round-1 record, kept as they were. Round 1's issue 1 (`analysis_options.yaml`) is fixed in round 2.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| L1 to L3 tests | `tool/bazelw test --nocache_test_results //...` | **43/43 pass** ([`verifier/gate-test.log`](verifier/gate-test.log)) |
| L0 lint (analyze and format) | `tool/bazelw build --config=lint //...` | **pass** ([`verifier/gate-lint.log`](verifier/gate-lint.log)) |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | **`mc_arch_check: OK`** ([`verifier/gate-arch.log`](verifier/gate-arch.log)) |
| Coverage (ADR-0010, ≥ 90 %) | `tool/bazelw coverage --nocache_test_results //utility/mc_test_utils/...`, then my own union merge of the 5 `coverage.dat` files ([`verifier/probes/merge_cov.py.txt`](verifier/probes/merge_cov.py.txt)) | **97.8 % (272/278)**. All 6 `lib/src` files are present in LCOV. The only misses are 1 line in `backend_harness.dart` (`close`) and 5 font-lookup fallback lines in `golden.dart`. This matches the Engineer's figure ([`verifier/coverage.txt`](verifier/coverage.txt)). |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s), plus Verifier probes | Does the test really assert the AC? | Result |
|---|---|---|---|---|
| T-0026-AC1 | An unfixtured endpoint fails the test, naming the route | `harness_test` "T-0026-AC1 an endpoint with no fixture set fails by route", "T-0026-AC1 session is unavailable outside mcTestWidgets". **Probe** `verifier_ac1_probe_test` (expected to fail): 3 unacknowledged cases (a) no fixture set, (b) the wrong fixture set active, (c) the body fails first. Plus a fixtured control. | Yes. The Engineer's test asserts `verify()` / `guard()` throw and then acknowledges. My probe shows that a real `mcTestWidgets` test **fails** with `Unmatched request GET /v1/verifier/unfixtured` (and `.../missing` with `active: verifier.basic`; `.../elsewhere` plus `The test body failed: …`). The control passes. See [`verifier/ac1-probe-expected-fail.log`](verifier/ac1-probe-expected-fail.log). Mutant "unmatched never recorded" is killed. | **PASS** |
| T-0026-AC2 | A second test sees fresh DI, backend, platform and surface under random seeds | `isolation_test` "T-0026-AC2 isolation, first" / "second". **Probe** `verifier_probe_test` group "VPROBE-AC2 A/B/C": each asserts a fresh world, then dirties it. The dirt: an `ExternalDouble` in DI, a fixture set, an always-failing 500 rule exercised through the flow, a monitoring event, a file in the storage dir, text scale 3, locale `fr`, the `highContrastDark` theme, an Android platform override, and a 10x20 @3x surface. The fresh check also asserts a new session object, that the predecessor's temp dir is deleted, and that the pumped `MediaQuery` text scale is 1. | Yes. I ran 7 seeds (1, 7, 42, 1234, 99999, 31337, 271828) over `isolation_test`, `harness_test`, `init_flow_test` and my probe. All pass. Both orders of first/second were observed, and several A/B/C orders ([`verifier/seeds.log`](verifier/seeds.log)). The `tearDownAll` counters prove that a dirty predecessor really ran. | **PASS** |
| T-0026-AC3 | `fail(times: 1)` then the retry succeeds; `hold`/`release` shows loading with no timers | `harness_test` "T-0026-AC3 fail(times: 1) fails once, the retry succeeds", "T-0026-AC3 hold keeps loading observable until release". **Probes:** (1) `fail(times: 1)` **and** `hold` on the same route: `loading` stays through `pump(5 min)` of fake time (no Dio timeout, retry delay or latency timer releases it), there is 1 request and no backend traffic; after `release`, traffic is `[500, 200]` and `ok:7`. (2) `times: 3` exhausts the initial request plus 2 automatic retries (`failed:500`, 3 requests); a user retry then gives `ok:7`, traffic `[500, 500, 500, 200]`. | Yes. The mutants "fail ignores times" and "hold does not block" are both killed by the Engineer's tests and by my probes. | **PASS** |
| T-0026-AC4 | `initFlow` gives the DS theme, `en` and iOS; exports; coverage ≥ 90 % | `init_flow_test` "T-0026-AC4 initFlow gives the DS theme, en and iOS"; `golden_test` (8 "T-0026-AC4 probe golden …"). **Probe** "VPROBE-AC4": inside the flow, `Theme.of` has the DS `colorScheme`, scaffold colour, Inter body font and `McThemeExtension` (light). `Localizations.localeOf` is `en`. `defaultTargetPlatform` and `theme.platform` are iOS. `diContainer<Monitoring>()` is the session's `MockMonitoring`. `McTestContainer.dio` and `createMockMonitoring` are used through the **barrel only**. | Yes. Coverage is 97.8 % (above). The probe golden PNGs show real Inter glyphs, not Ahem (checked `probe.dark.x2.png`). | **PASS** |

The probe sources are kept in [`verifier/probes/`](verifier/probes/) (as `.txt`). They were run from temporary `flutter_test` targets in my worktree and are **not** committed as code.

## Mutation (ADR-0006 anti-gaming)
Each mutant was applied with `sed`, tested, then reverted with `git checkout` ([`verifier/mutation.log`](verifier/mutation.log), script in `verifier/probes/mutate.sh.txt`).

| Mutant | Killed by |
|---|---|
| Skip `resetDIContainer()` in `_start` **and** `_finish` | `T-0026-AC2 isolation, second` (plus 3 more in `isolation_test`) and VPROBE-AC2 B and C |
| Skip it in `_start` only / in `_finish` only | **Survives** (equivalent mutant): the other call still resets, so either reset alone is enough. This is defence in depth, not a gap. |
| Unmatched requests never recorded | `T-0026-AC1 an endpoint with no fixture set fails by route` |
| `fail()` ignores `times` (always fails) | `T-0026-AC3 fail(times: 1)…` and both VPROBE-AC3 probes |
| `hold` does not block | `T-0026-AC3 hold keeps loading observable…` and VPROBE-AC3 (1) |

## Tide conformance (`test_utils`, research §4.4 and plan 05 TD-01 to TD-04)
| Tide | Ours | Deviation and assessment |
|---|---|---|
| `FeatureTestInterceptor`: a Dio interceptor, path-only, raw JSON, **throws** at request time | `McBackendHarness`: an `HttpClientAdapter` wrapper over `mc_mocked_backend`. It matches method, path and a query subset, offers typed `BackendFailure` × `times`, and Completer holds. An unmatched request is **recorded**, still answered with a 404 (so the app's error path runs), and fails the test in `verify()` / `guard()`. | This is TD-01 as planned. Deferring the failure to the end of the test is better than Tide's throw: the route is still named, and the message is prefixed even when the body fails first (F-0022 #4). Fixture sets come from an in-code registry (`McFixtureSets.register`), not "from the test's own assets" as plan §1.2 says. |
| `TestContainer`: a bare `Dio()` that replaces the whole utility layer | `McTestContainer`: config, monitoring, storage, backend, the **real** `ApiClientDIInitializer` (`retryDelay: 0`), event bus, wirings, externals | This is TD-02 in spirit. The plan's `rootInitializers().overriding()` is impossible because of layering, so the list is duplicated. It matches today's `app_core` `rootInitializers` 1:1 by type, but it can drift (follow-up: a drift guard). There is no `ClockTestInitializer` yet, because no clock package exists. |
| `MockMonitoring` (mocktail), not exported | A hand-written recorder over `InMemorySink`, **exported**, same names | Because there is no mocktail in the lock (F-0022 #1). TD-03 is satisfied. |
| `initFlow` with `GetIt.reset()` in production init and a bare `MaterialApp` | `initFlow(tester, flow, externals:)`, pumping `McTestApp` (DS theme variant, locale, text scale, iOS). The reset moved into `McTestSession` (start and finish). | TD-04 and 01 D-17 as planned. There are no global l10n delegates yet (T-0025 is pending). |
| Not in scope (plan §1.2) | `expectScreenGolden`, `GoldenDevice`, `expectIosAccessibility`, `servedStrings`, `@isTest`, `MC_BACKEND_CHAOS` | Not built. The Outcome lists these as follow-ups. No AC needs them. |

## Hygiene
- **testonly:** `flutter_library(testonly = True)` for both `mc_test_utils` and the `mc_ds_testing` shim. `bazel query 'rdeps(//..., //utility/mc_test_utils:mc_test_utils) except attr(testonly, 1, //...)'` returns **nothing**.
- **Root change:** the only root change is one line in the `pubspec.yaml` workspace list (`utility/mc_test_utils`). There are no changes to `pubspec.lock`, `MODULE.bazel*` or `.bazelrc`. `fvm flutter pub get --enforce-lockfile --offline` succeeds.
- **The `mc_ds_testing` shim:** it re-exports the 6 golden symbols. `golden.dart` is a verbatim move: a diff against the old `mc_ds_testing.dart` shows only the doc comment and one `dart format` line-join. The 4 `mc_ds_*` golden tests (`mc_ds_buttons`, `mc_ds_feedback`, `mc_ds_layout`, `mc_ds_theme`) still import `mc_ds_testing` and **pass**. `fonts_test` moved unchanged (only its import changed).
- **Test integrity:** no tests deleted, skipped or weakened (`fonts_test` was moved, not removed). No `// ignore:` was added. The golden files are 8 new `probe.*` PNGs; no existing golden was changed.

## Issues found
1. **(low, hygiene)** `utility/mc_test_utils/analysis_options.yaml` lacks the `analyzer: exclude: [build/**]` block that the other Flutter packages carry (for example `mc_feature_flow`). Running `fvm flutter pub get` therefore rewrites the file and dirties the tree ("Upgrading analysis_options.yaml to exclude build and platform directories"). I reverted that change. It does not affect any AC. Fix: add the block.
2. **(low, design note)** `McFixtureSets` is a process-global registry. Which sets are *active* is per test and fresh (AC2), but a name registered inside one test's body stays registered for later tests in the same isolate. The documented use is to register in `main()`, so this is harmless. It is worth a line in the eventual `mc_test_utils` README or the steps library.
3. **(info)** The AC1 message comes from the end-of-test `verify()`, not from the request itself. A test that hits an unfixtured route and then hangs, or times out on `pumpAndSettle`, gets the route prefixed only when the body throws (that path is covered by `guard`). This is acceptable as designed.

## Notes for the Tech Lead
- The single-reset mutants survive by design (the start and finish resets are redundant). If you want each reset pinned on its own, add a plain `testWidgets` after an `mcTestWidgets` test that asserts an empty `diContainer`. That pins the `_finish` reset.
- The Engineer's finding `F-0022` (to be renumbered F-0024) is accurate on every point I checked: no mocktail, the duplicated root list, zero retry delay, strictness in the adapter wrapper, Completer holds, `try/finally` restores, the seed flag honoured under Bazel, and the shim.

---

## Round 2: review fixes at `608796a`
Evidence is in [`verifier2/`](verifier2/). The probe sources are in `verifier2/probes/` (as `.txt`). They ran from temporary targets and are not committed as code.

### Gates re-run
| Gate | Result |
|---|---|
| `tool/bazelw test --nocache_test_results //...` | **43/43 pass**, including `//utility/mc_mocked_backend:mocked_backend_test` ([`verifier2/gate-test.log`](verifier2/gate-test.log)) |
| `build --config=lint //...` | **pass** |
| `run //tool/mc_arch_check:bin` | **OK** |
| Coverage, `mc_test_utils` | **97.7 % (300/307)**, my own merge. The misses are `backend_harness.dart` 294 and 345 plus 5 font-fallback lines ([`verifier2/coverage.txt`](verifier2/coverage.txt)). |
| Coverage, `mc_mocked_backend` (changed) | **92.5 % (273/295)** on its own tests. `addDomain` (lines 106 and 107) is covered only through `mc_test_utils`; see issue R2-2. |
| Random ordering | Seeds 5, 77, 2024 and 65535 over `isolation_test`, `harness_test`, `init_flow_test` and my probe: all pass ([`verifier2/seeds.log`](verifier2/seeds.log)) |

### The review fixes, checked with my own probes (`verifier2_probe_test`: 14/14 pass, [`verifier2/probe-pass.log`](verifier2/probe-pass.log))
| # | Fix | Probe and what it shows | Result |
|---|---|---|---|
| 1 | Externals must be typed and must not duplicate a type that is already registered | V2-1: an untyped `ExternalDouble(_Marker)` through `initFlow` throws `StateError` naming `ExternalDouble<_Marker>`. `ExternalDouble<Object>`, `<Monitoring>`, `<AppConfig>`, `<Dio>`, `<MockBackend>`, and a second `<_Marker>` are all rejected. After each failure, `containerInitialized` stays false and nothing is published (`Dio` is unregistered). A typed external then works, and the flow shows `ok:7`. | **PASS** |
| 2 | Fixture-set scenarios go through `MockBackend.addDomain` | V2-2: a fixture set with two scenarios. `scenarioNames` lists both, and an unknown name throws `ArgumentError`. `v_once` gives traffic `[500, 200]` and `ok:7`. `v_down` then gives `failed:503`, and `useScenario(null)` gives `ok:7`. `useDomain` registers scenarios too. The `mc_mocked_backend` change is a pure extraction (`_register`, shared by the constructor and `addDomain`). Its test diff is reformatting only (no assertion changed), and its suite passes. | **PASS** |
| 3 | A malformed URL is a 400, not a raw `FormatException` | V2-3: a malformed `:param` segment (`/v1/verifier/p/%FF`) and malformed queries (`?q=%FF`, `?q=%E0%A4%A`, also on an unrouted path) each give **400**, are not flagged unmatched, and raise no exception. **Nuance:** a malformed segment that no route *pattern* could take (`/v1/verifier/items/%FF`, `/v1/nowhere/%FF`) gives **404** and is flagged unmatched, because the engine decodes only `:param` segments. That is sane, and still no raw exception, but F-0024 #13 overstates it (issue R2-1). | **PASS** |
| 4 | `fail()` on an unrouted path | V2-4: with `times: 3`, the request and its 2 automatic retries give `[500, 500, 500]` with **no** unmatched entry. The user's retry gives 404 and is flagged `GET /v1/verifier/ghost`. Two stacked `times: 1` rules mirror the engine's counting: `[500, 500, 404]`, flagged only on call 3. An always-failing rule is never flagged (6 calls). A query-subset rule (`?a=1`) does not cover `?a=2`, which is flagged. | **PASS** |
| 5 | A held, then cancelled request | V2-5: two held requests, one with a `CancelToken`. On cancel it fails with `DioExceptionType.cancel` and **never reaches the engine** (`recentTraffic` is empty). After `release`, the other request answers 200 and the traffic is exactly `[200]`. | **PASS** (see issue R2-3) |
| 6a | `containerInitialized` is set only after success | V2-1, plus V2-6: a throwing wiring leaves the flag false, and a later `initialize` succeeds | **PASS** |
| 6b | The session is built before any global is touched | Code read: `mcTestWidgets` builds `McTestSession._()` (backend, monitoring, temp dir) before `_setUp`, and `_setUp` runs inside the `try`, so `_finish` always restores | **PASS** |
| 6c | The stack trace is kept | `verifier2_stack_probe_test` (expected to fail): the failure reads `Unmatched request GET /v1/verifier/unfixtured … The test body failed: Bad state: thrown by verifierThrower`, and the stack starts at `#0 verifierThrower (…verifier2_stack_probe_test.dart:16)` ([`verifier2/stack-probe-expected-fail.log`](verifier2/stack-probe-expected-fail.log)) | **PASS** |
| 6d | Subset runs work | `--test_filter="T-0026-AC2 isolation, first"`: 1 passed, and `tearDownAll` does not fail ([`verifier2/subset-run.log`](verifier2/subset-run.log)). The runner rejects `--plain-name` (only `--update-goldens` and the seed are accepted as test args); `--test_filter` is the Bazel way. | **PASS** |
| 6e | `analysis_options.yaml` is dropped (F-0021) | `utility/mc_test_utils/` has no options file. `fvm flutter pub get --enforce-lockfile --offline` leaves the tree clean. Lint passes under the root options. | **PASS** |

### Mutation (round 2, [`verifier2/mutation.log`](verifier2/mutation.log))
| Mutant | Killed by |
|---|---|
| `fail()` not mirrored (`_failRules.add` removed) | `T-0026-AC3 a failed unrouted path is answered, not unmatched`, plus 3 V2-4 probes |
| Untyped `ExternalDouble` accepted (`T == Object` → `T == Never`) | `T-0026-AC2 externals need an explicit, unclaimed type`, plus V2-1 |
| `useDomain` back to `domain.register` (no scenarios) | `T-0026-AC3 fixture-set scenarios are selectable`, plus both V2-2 probes |
| The held request ignores cancellation (`await hold.gate.future`) | **Only my V2-5 probe.** The Engineer's `T-0026-AC3 a held request honours cancellation` **survives** (issue R2-3) |

All mutants were reverted. `git status` was clean before the final gates.

### Round-2 issues
- **R2-3 (low, test gap):** the Engineer's cancellation test does not pin the fix. Dio's core already completes a cancelled call with `DioExceptionType.cancel`, whatever the adapter does. Without the fix, the caller sees the same error, but the held request **still reaches the engine on `release`** (my probe saw traffic `[200, 200]` instead of `[200]`). For a POST, that would be a phantom write. **Suggested fix:** in that test, `release` and pump, then assert `backend.backend.recentTraffic` is empty, or holds only the uncancelled request. The fix itself is correct (V2-5).
- **R2-1 (low, docs):** F-0024 #13 says that `/v1/x/%FF` gets a 400. In fact that is true only when a `:param` route has that shape. Otherwise it is a 404 and the request is flagged unmatched (malformed queries are always 400). Worth one sentence in F-0024.
- **R2-2 (low, coverage locality):** `MockBackend.addDomain` has no test in `mc_mocked_backend` itself (ADR-0010: utilities prove themselves). The package stays at 92.5 %, so no gate fails. A one-line test (add a domain, then assert its route answers and its scenario is listed) would close the gap.
- **R2-4 (info):** two fixture sets whose domains declare the same scenario name cannot both be active: `_register` throws `Duplicate scenario` **after** registering the second domain's routes. This is unlikely in practice (one set per domain per test), but worth knowing when several sets of one domain are composed.

**Round-2 verdict: PASS.** Every AC still passes, every fix the coordinator listed works as described (fix 3 with the R2-1 nuance), and the gates and coverage are green.
