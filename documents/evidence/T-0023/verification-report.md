# Verification report: T-0023: `mc_api_errors` + `mc_api_client`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0023-api-client` @ **`e7f93dc`**, checked out as `fleet/T-0023-verify2`. That is `bf39482` plus the review fixes `018e613` plus the FAIL fixes `e7f93dc`. This report replaces my first pass on `bf39482` (branch `fleet/T-0023-verify`, commit `f630f7b`, which was FAIL on AC5). The first-pass findings are summarised under "First pass" below.
- **Simulator:** none. This is a pure-Dart utility task with no UI and no e2e.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0023-verifier`, used by this Verifier only and shut down at the end. The check script ran through an `MC_BAZELISK` wrapper that adds the same output base.
- **Verdict:** **PASS**. Every AC passes. The AC5 failure from the first pass is fixed, and its fix is guarded by a check that I watched fail.

## Gates re-run independently (at `e7f93dc`)
| Gate | Command | Result |
|---|---|---|
| All tests | `tool/bazelw test --nocache_test_results //...` | **31/31 PASS**. `mc_mocked_backend:mocked_backend_test` is now a `dart_test`. |
| Analyze + format | `tool/bazelw build --config=lint //...` | OK |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| AC5 closure | `tool/checks/T-0023-AC5_flutter_free.sh` | **PASS** with `cycle_breaks`. **FAIL** (exit 1) with the line removed. Reverted. |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0023-AC1 | Timeout, offline, 401, 404, 500 and malformed map to the matching `ApiFailure` through `mc_mocked_backend` | `mc_api_client:api_client_test` (the original 6 plus "other 4xx is a client error"); `mc_api_errors:api_failure_test` (now with 422) | Yes. **My black-box suite** (temporary, re-run on `e7f93dc` and then removed): timeout, offline, 401, 404, 500, 503, malformed, 400 and 403 gave `ApiTimeout`, `ApiOffline`, `ApiUnauthorized`, `ApiNotFound`, `ApiServer(500)`, `ApiServer(503)`, `ApiMalformed`, `ApiClientError(400)` and `ApiClientError(403)`. **Mutation (this pass):** I mapped the other-4xx case to `ApiUnexpected`. Both the mocked-backend test and the direct test FAILED. Reverted. First pass: 404 → `ApiServer` was caught. | PASS |
| T-0023-AC2 | GET 503 with retry 2 makes 3 attempts; a POST is never retried | `api_client_test` "T-0023-AC2" (the original 5 plus 4 new ones: FormData, stream body, receive timeout, cancel during backoff) | Yes. Attempts are counted with `backend.recentTraffic`. **My suite:** GET 503 made exactly 3 attempts. Retries 0, 1, 2 and 5 gave 1, 2, 3 and 6. POST and PATCH made 1 attempt for 503, connect timeout and offline. PUT and DELETE 503 made 3. GET 401 and 404 made 1. The DI Dio made 3 attempts with 1 log line each. First pass: making POST retryable was caught. | PASS |
| T-0023-AC3 | `ApiFailure.from(TypeError)` gives `unexpected` and keeps the message | `api_failure_test` "T-0023-AC3" | Yes. **My check:** a real `TypeError` inside `apiCall`, after a 200 response, gave `ApiUnexpected(_TypeError: type 'List<dynamic>' is not a subtype of type 'int' in type cast)`. First pass: dropping the message was caught. | PASS |
| T-0023-AC4 | `diContainer<Dio>()` is one shared instance on the mock adapter, and `/v1/characters` returns page 1 | `api_client_test` "T-0023-AC4" (3 tests: config base URL, explicit override, missing `Monitoring` fails loudly) | Yes. **My check:** I wired `ConfigDIInitializer` (`apiBaseUrl` `https://cfg.test`), `MonitoringDIInitializer` and `ApiClientDIInitializer(adapter: backend.adapter)`. The instance was identical across lookups, its adapter was identical to `backend.adapter`, and `baseUrl` was `https://cfg.test`. The response was 200 with `offset 0` and 20 results, and the backend recorded one `GET /v1/characters`. | PASS |
| T-0023-AC5 | Gates pass; both packages are Flutter-free (R15) | gates, `*:no_flutter_test` x2, `tool/checks/T-0023-AC5_flutter_free.sh` | **Yes.** I ran `cquery 'deps(//utility/<pkg>)'` myself: `mc_api_errors` has 1,359 targets and `mc_api_client` has 1,395. In both, `sky_engine`, `pub_deps__flutter`, `@@rules_flutter` / `//flutter:` and `mc_mocked_backend` each occur **0** times. `dio` is now the single-package spoke `pub_deps__dio//:dio`, not the SCC. **Negative check:** with `cycle_breaks` removed, the script printed `pub_deps__flutter//:flutter` for both packages and closures of 2,685 and 2,714 targets, and exited 1. Reverted with `MODULE.bazel` and `MODULE.bazel.lock` restored. First pass: `no_flutter_test` catches a direct `export 'package:flutter/…'`. | PASS |

## Review fixes (requested checks)
| Check | Result |
|---|---|
| FormData cloned per attempt; streams not retried | Yes. `options.data is FormData ? clone() : data` on each retry, and `_replayable` refuses a `Stream` body. Tests: PUT with FormData makes 3 attempts and surfaces `ApiServer(503)`, not a "finalized" `StateError`. PUT with a stream makes 1 attempt. |
| Receive timeouts not retried | Yes. `_retryable` is now connect timeout, connection error and 5xx only. `sendTimeout` was dropped too, which is reasonable. Test: a slow route with a 20 ms receive timeout gives `ApiTimeout` after 1 attempt. |
| Backoff honours the cancel token | Yes. `Future.any([delay, token.whenCancel])`, then a `requestCancelled` exception. Test: cancelling during a 30 s backoff returns within 5 s, with a message containing "cancel" and 1 attempt. |
| `ApiClientError` for other 4xx | Yes. `ApiClientError(status)` covers 4xx other than 401 and 404. It is a new case in the sealed family. |
| `apiBaseUrl` from `AppConfig`, plus override | Yes. `AppConfig.apiBaseUrl` is required and present in `dev.json`, `e2e.json` and `perf.json`. The initializer uses `baseUrl ?? getIt<AppConfig>().apiBaseUrl`. Both paths are tested, and I checked the config path myself. |
| Monitoring resolved per request | Yes. `Monitoring Function()` is passed to the interceptor. If `Monitoring` is missing, the request throws (tested). |
| `dio ^5.11.0` | Yes, in all three pubspecs. `pubspec.lock` already had `dio 5.11.1`, so the lock is unchanged. |
| `ApiUnexpected` message format | Yes. The wrapped-error branch is now `'${inner.runtimeType}: $inner'`, the same format as `ApiFailure.from`'s fallback. |
| Dependency direction | `mc_mocked_backend` is only in `mc_api_client`'s `dev_dependencies` and its `api_client_test` deps. It is absent from the `dart_library` deps and from the cquery closure. `ApiClientDIInitializer` takes an `HttpClientAdapter`, which matches plan 01 §5's app-only wiring. |

## Conformance
- **Tide's `api_client`:** it matches. One shared `Dio` is registered in DI. Cross-cutting concerns are interceptors. Features declare their own retrofit APIs over the injected `Dio`, and nothing here prevents that. The failure model, `apiCall` and the retry policy are the deviations that P1-05 asks for.
- **Flutter-free:** both packages are Flutter-free at the source level and in the Bazel closure.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. The `mc_mocked_backend` test moved from `flutter_test` to `dart_test` (`package:test`). Its one-line test change is the import, and the assertions are unchanged.
- Lint suppressions added: none.
- Golden files updated: none.
- My temporary `vfy_test`, the mutation and the `cycle_breaks` removal were all reverted. `git status` was clean before this report.

## Hygiene
Root changes relative to `origin/main`:
- `pubspec.yaml`: the 2 workspace entries.
- `MODULE.bazel`: the `cycle_breaks` line, approved by the TL.
- `MODULE.bazel.lock`: only the regenerated `flutter.pub` extension, with the dio SCC entries replaced by separate spokes.
- `tool/bazel/config/{dev,e2e,perf}.json`: `apiBaseUrl`.
- `tool/checks/T-0023-AC5_flutter_free.sh`.

Outside the two packages, `mc_config` changed (`apiBaseUrl`) and `mc_mocked_backend` became pure Dart, with its `flutter` SDK constraint and `flutter_test` removed. Nothing generated is committed.

## Issues found
1. **(low, carried over)** `ApiFailure.message` for an HTTP error is Dio's multi-line explanatory text. It's fine for logs. Features must not render it to users.
2. **(low, carried over)** The retry marker (`mc_api_client.retrying`) stays in the final error's `requestOptions.extra`. If `mc_api_auth` later replays `err.requestOptions` after a token refresh, that replay won't be retried. Note it for the `mc_api_auth` task.
3. **(low)** The check script runs `tool/bazelw cquery` on the default output base. Parallel crew should run it with `MC_BAZELISK` pointing at a wrapper that adds their own `--output_base`, as I did, or the script should accept an output base.

## First pass (`bf39482`, superseded)
- **FAIL on AC5:** `@pub_deps//:dio` was the rules_flutter SCC spoke, which always depends on `@pub_deps__flutter//:flutter`. That pulled `sky_engine` into both closures. Now fixed by `cycle_breaks` and recorded in F-0019.
- **Medium:** `mc_api_client`'s `lib` depended on `mc_mocked_backend`, the reverse of plan 01 §5. Now fixed by injecting the adapter.
- **Low:** other 4xx mapped to `ApiUnexpected`. Now fixed by `ApiClientError`.
- **Process:** I shared an output base with the T-0022 Verifier, and my shutdown killed its server. This pass used `/tmp/mc-ob-T-0023-verifier`.

## Notes for the Tech Lead
- F-0019's upstream candidate (rules_flutter should not mark a merged SCC as Flutter unless a member depends on Flutter) is still unfiled. That is the TL's call.
