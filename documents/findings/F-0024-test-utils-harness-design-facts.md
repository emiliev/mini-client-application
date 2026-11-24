# F-0024: `mc_test_utils` harness: what differs from the plan and why

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0026)
- **Type:** Gotcha / deviation record
- **Related:** T-0026, plan 05 §1.2 and TD-01, TD-02, F-0014, F-0015

## Summary
1. **No `mocktail` in the lock.** `MockMonitoring` is a hand-written `Monitoring` subclass over `InMemorySink` (it records `entries`, `logs`, `events`, `errors`). It keeps the names `MockMonitoring` and `createMockMonitoring()`. If `mocktail` is added to the root lock later (P5 decision), only `mocks.dart` changes.
2. **A utility cannot import `app_core`** (`mc_arch_check`: a utility depends on utilities only), so `McTestContainer.initializers` repeats the production root list (config, monitoring, storage, mocked backend, API client, event bus) with the doubles at the edges. The plan's `rootInitializers(...).overriding(...)` is therefore not possible as written. **Drift guard (follow-up):** a test in `app_core` that depends on `mc_test_utils` and asserts both lists register the same types. Until then, adding a root initializer to `app_core` means adding it to `test_container.dart`.
3. **`retryDelay: Duration.zero` in the test container.** The production retry interceptor waits with `Future.delayed(200 ms * n)`; under `testWidgets` that is a fake-async timer nobody pumps. With zero delay a failed first request and its retry both complete on `pump()`, so AC3's "first fails, retry succeeds" needs no timers.
4. **Strictness lives in the adapter wrapper, not in the engine.** `mc_mocked_backend` answers an unrouted request with a 404 (correct for the app and e2e). `McBackendHarness` wraps its adapter, checks `router.resolve` first, records `METHOD path` as unmatched, and still forwards (the app sees the 404 and its error state). `verify()` then fails the test with `Unmatched request GET /v1/...`. When the body throws first, `McTestSession.guard` prefixes the unmatched routes to the error so the route is named.
5. **Holds are `Completer`s, not timers.** A held request awaits a gate in the adapter; the loading state stays visible with no clock involved. `mcSettle` pumps two frames (not `pumpAndSettle`) while a hold exists.
6. **Globals are restored inside the test body (`try/finally`), not with `addTearDown`**: `debugDefaultTargetPlatformOverride` is checked by the framework's invariant check before tear-downs run (F-0014 fact 5). The tree is unmounted first so `FeatureFlow` disposes its child container.
7. **`@isTest` is not available** (`meta` is not a declared dependency), so `mcTestWidgets` is not recognised as a test method by IDE runners.
8. **Random ordering works under Bazel**: `--test_arg=--test-randomize-ordering-seed=<n>` is honoured by the `flutter_test` rule (the log prints the seed). The AC2 test makes each of its two tests assert a fresh world and then dirty it, so the check is meaningful in either order.
9. **`mc_ds_testing` is now a re-export shim** of the golden helpers (P-033). Its `fonts_test` moved to `mc_test_utils`. The `mc_ds_*` golden tests keep their import and now pull in `mc_test_utils`'s closure (api client, backend, di, ...). Migrating them to import `mc_test_utils` directly and deleting the shim is a follow-up.
10. **Coverage** was measured with `bazel coverage` and the per-target `coverage.dat` files merged by union (script in the evidence). The package is at 97.8 % (272/278); see `documents/evidence/T-0026/engineer/coverage.txt`.

## Implications
- Feature tests call `McFixtureSets.register('<domain>.<set>', ...)` once (in `main()`), then `backend.useFixtureSet(...)` per test.
- Golden-targets need `data = ["//utility/mc_ds_theme:fonts"]` for any `mcTestWidgets` test, because it loads the fonts for every test.

## Review round (fixes after `/code-review`)
11. **`ExternalDouble` needs an explicit type.** `ExternalDouble(x)` infers `Object`; `toInitializer` throws naming the type to write (`ExternalDouble<Clock>(x)`). An external whose type the root list already registers is **rejected** (not overridden) with a clear message.
12. **Fixture-set scenarios** are registered: `MockBackend.addDomain(domain)` (new, small, TL-approved) shares the constructor's route and scenario registration, and `useDomain` uses it.
13. **Malformed URLs** (`/v1/x/%FF`, `?q=%FF`) are forwarded; the engine answers 400. The harness does not mark them unmatched.
14. **A failed unrouted path** is not unmatched while one of the harness's own `fail` rules fires for it (the adapter mirrors the engine's counting).
15. **A held request honours cancellation**: the adapter waits on the gate or `cancelFuture` and throws `DioException.requestCancelled`.
16. Under `fake_async`, a Dio call needs several event-loop turns: use `tester.pump(Duration(milliseconds: 100))` (zero-duration pumps were not enough for cancellation) or `tester.runAsync` (works for plain requests; a `CancelToken` cancelled inside it did not reach the adapter).
17. `mc_test_utils` has no per-package `analysis_options.yaml` (F-0021: `pub get` rewrites it and it drops the root formatter setting), like the `mc_ds_*` packages.
