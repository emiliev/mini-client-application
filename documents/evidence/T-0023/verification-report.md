# Verification report: T-0023: `mc_api_errors` + `mc_api_client`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0023-api-client` @ **`bf39482`**, checked out as `fleet/T-0023-verify`
- **Simulator:** none. This is a pure-Dart utility task with no UI and no e2e.
- **Bazel:** `tool/bazelw --output_base=<verifier scratch>`, a private output base, shut down at the end.
- **Verdict:** **FAIL**, on AC5's "Flutter-free (R15)" only. AC1 to AC4 pass. Both packages' Bazel closures reach `package:flutter` and `sky_engine` through `@pub_deps//:dio` (Issue 1). The cause is a third-party target, not the Engineer's code. The fix is one line in `MODULE.bazel`, and I tested it.

## Gates re-run independently (at `bf39482`)
| Gate | Command | Result |
|---|---|---|
| All tests | `tool/bazelw test --nocache_test_results //...` | **31/31 PASS** |
| Analyze + format | `tool/bazelw build --config=lint //...` | OK |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0023-AC1 | Timeout, offline, 401, 404, 500 and malformed each map to the matching `ApiFailure` through `mc_mocked_backend` | `mc_api_client:api_client_test` (6 tests through `FailureRule`s); `mc_api_errors:api_failure_test` (direct) | Yes. Each test runs a real `FailureRule` through the adapter, `createApiDio` and `apiCall`, and checks the subtype. The 500 test also checks `status`. **My checks** (temporary `vfy_test`, now removed): all 6 kinds plus 503, 400 and 403 gave `ApiTimeout`, `ApiOffline`, `ApiUnauthorized`, `ApiNotFound`, `ApiServer(500)`, `ApiServer(503)`, `ApiMalformed` (`FormatException: Unexpected end of input`), `ApiUnexpected` and `ApiUnexpected`. **Mutation:** I mapped 404 to `ApiServer`. Both `T-0023-AC1: 404` and the direct test FAILED. Reverted. | PASS |
| T-0023-AC2 | GET 503 with retry 2 makes 3 attempts; a POST is never retried | `api_client_test` "T-0023-AC2" x5 | Yes. The attempts are counted with `backend.recentTraffic`, which is the backend's own record. **My checks:** GET 503 traffic was exactly 3 entries, all `GET 503`. Retries 0, 1, 2 and 5 gave 1, 2, 3 and 6 attempts. POST and PATCH made 1 attempt each for 503, timeout and offline. PUT and DELETE 503 made 3. GET 404 and GET 401 made 1. The DI-built Dio (default retries 2) also made 3 attempts, with 1 log line per attempt. **Mutation:** I added `POST` to the idempotent set and `a POST is never retried` FAILED. Reverted. | PASS |
| T-0023-AC3 | `ApiFailure.from(TypeError)` gives `unexpected` and keeps the message | `api_failure_test` "T-0023-AC3" | Yes. It causes a real `TypeError` with a bad cast and checks that the message contains `'$thrown'`. **My check:** I threw a `TypeError` inside `apiCall`, after a real 200 from `/v1/characters` (`results` cast to `int`). The result was `ApiUnexpected(_TypeError: type 'List<dynamic>' is not a subtype of type 'int' in type cast)`, which contains the original text. **Mutation:** I replaced the mapping with `const ApiUnexpected()` and AC3 FAILED (`Actual: 'Unexpected error'`). Reverted. | PASS |
| T-0023-AC4 | `diContainer<Dio>()` is one shared instance on the mock adapter, and `/v1/characters` returns page 1 | `api_client_test` "T-0023-AC4" | Yes: `identical` across two lookups, `same(backend.adapter)`, and `offset 0`, `total 1500`, non-empty `results`. **My check:** I wired `MonitoringDIInitializer` and `ApiClientDIInitializer`. The instance was identical across lookups and the adapter was identical to `backend.adapter`. The response was 200, `offset 0`, 20 results (the default limit), and the backend recorded exactly one `GET /v1/characters`. | PASS |
| T-0023-AC5 | Gates pass; both packages are Flutter-free (R15) | gates; `*:no_flutter_test` x2 | **Gates: yes.** The `no_flutter_test` checks catch a direct import: I added `lib/src/zz_vfy.dart` with `export 'package:flutter/foundation.dart';` and `mc_api_errors:no_flutter_test` FAILED, naming the file. Removed. **R15 "directly or transitively": no.** `bazel query 'somepath(//utility/mc_api_errors, @flutter_sky_engine//:sky_engine)'` gives `mc_api_errors → @pub_deps//:dio → …scc__dio__dio_web_adapter//:dio → sky_engine`. The same path reaches `@pub_deps__flutter//:flutter`. `aquery` of `mc_api_errors`'s `DartAnalyze` action lists `pub_deps__flutter/flutter.dart_analyzer_summary.sum` and `sky_engine.embedder_sdk.sum` as inputs. No first-party file imports Flutter. See Issue 1. | **FAIL** |

## Conformance
- **Tide's `api_client` (research §4.4, §5.5):** it matches. There is one shared `Dio`, configured once and registered in DI (`registerSingleton`; Tide uses `@lazySingleton`). Cross-cutting concerns are interceptors (logging, retry). Features are meant to declare their own retrofit APIs that take this `Dio`, and nothing in the package prevents that. The deliberate deviations from Tide's §5.6 (no error types, no retry) are what P1-05 asks for: the sealed `ApiFailure`, `apiCall` over `Result.guard`, and retry for idempotent methods only. The barrel exports more than Tide's (`createApiDio` and the interceptors), which is harmless.
- **Flutter-free:** yes at the source level, no in the Bazel closure (AC5, Issue 1). The `dart_library` closure is otherwise `mc_api_errors`, `mc_di`, `mc_mocked_backend`, `mc_monitoring`, `mc_prelude`, `dio`, `get_it` and pure-Dart pub packages. `mc_fixtures_characters` (which brings the Flutter `mc_fixtures_media`) is a test dependency only.
- **Plan 01 §5 wiring:** this deviates from the plan. See Issue 2.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. Both packages are new.
- Lint suppressions added: none (no `ignore:` in the diff).
- Golden files updated: none.
- My temporary `vfy_test` target, the 3 mutations, the `zz_vfy.dart` probe and the `MODULE.bazel` cycle-break trial were all reverted. `git status` is clean apart from this report.

## Hygiene
- The only root change relative to `origin/main` is `pubspec.yaml`, with 2 workspace entries (`utility/mc_api_client`, `utility/mc_api_errors`). `pubspec.lock` and `MODULE.bazel` are unchanged. Everything else is under the 2 packages or `documents/`.
- Nothing generated is committed: no `.g.dart`, `.config.dart`, `.dart_tool` or `bazel-*`.

## Issues found
1. **(high, blocks AC5) `@pub_deps//:dio` drags `package:flutter` and `sky_engine` into every closure that uses Dio.** rules_flutter merges the `dio` ↔ `dio_web_adapter` cycle into one SCC spoke, and `flutter_pub_scc_spoke.bzl:394` (`_emit_scc_root_build`) always adds `@pub_deps__flutter//:flutter` to a merged SCC when `flutter` is in the lock. Neither pubspec declares Flutter. Single-package spokes such as `get_it` and `async` don't get it.
   - **Effect:** under plan 03 KD6 and F-0007, every codegen action over a library that reaches Dio has a Flutter closure. That is `mc_api_errors`, which KD6 names as pure Dart, plus every freezed bloc state that holds an `ApiFailure` and every retrofit API. Those actions either crash on the Flutter summary (F-0007) or have summaries switched off, which defeats the purpose of R15.
   - **Not caused by T-0023:** `mc_mocked_backend` has had the same path since T-0018 (`somepath` confirmed).
   - **Tested fix:** add `cycle_breaks = {"dio": ["dio_web_adapter"]}` to `flutter.pub(...)` in `MODULE.bazel`, as rules_flutter's README documents for this pair. The web adapter is only a conditional import for web, and we target iOS. With it, `somepath(//utility/mc_api_client, sky_engine ∪ @pub_deps//:flutter)` is empty, and `test --config=lint //utility/... //spike/...` passes 31/31. I did not check the iOS app build.
   - **Follow-up:** this is a root change, so the TL decides. It deserves a finding and an upstream issue against rules_flutter. A test that asserts no `sky_engine` in the closure would catch a regression better than `no_flutter_test`, which only greps the package's own `lib/`.
2. **(medium) `mc_api_client`'s `lib` depends on `mc_mocked_backend`, which inverts plan 01 §5.** The plan says "Wiring: app only. `MockedBackendDIInitializer` sets `dio.httpClientAdapter`", and puts the `NetworkDiagnostics` interface in `mc_api_client`, implemented by the mock.
   - **Problems:**
     - (a) When `NetworkDiagnostics` lands in `mc_api_client`, the dependency becomes a cycle (`mc_mocked_backend` → `mc_api_client` → `mc_mocked_backend`).
     - (b) Every feature that depends on `mc_api_client` gets the mock engine in its production closure.
   - **Partly in scope:** the task's Scope and AC4 do ask for an initializer that registers the Dio "with `mc_mocked_backend`'s adapter".
   - **Suggested fix:** `ApiClientDIInitializer` takes an `HttpClientAdapter` (the app passes `backend.adapter`), and `mc_mocked_backend` moves to the test dependencies. AC4 would still hold.
3. **(low) `ApiFailure.message` for an HTTP error is Dio's multi-line explanatory text** ("This exception was thrown because the response has a status code of 404 … Read more about status codes at https://developer.mozilla.org/…"). It is fine for logs. Features must not render `message` to users.
4. **(low) The retry marker stays in the final error's `requestOptions.extra`** (`mc_api_client.retrying: true`). If a later interceptor replays `err.requestOptions`, for example `mc_api_auth`'s refresh-and-replay, that replay will never be retried. Worth a note for the `mc_api_auth` task.
5. **(low, documented by the Engineer)** Any 4xx other than 401 and 404 maps to `ApiUnexpected('HTTP <n>: …')`, so a 400, 403, 409 or 422 has no typed case. That's acceptable for now, but forms (`mc_forms`) will probably want a `badRequest` or `validation` case.

## Notes for the Tech Lead
- AC1 to AC4 are solid. The tests assert what they claim, and each of my 3 mutations was caught by a test named for its AC.
- To turn this into a PASS: apply the `cycle_breaks` line (Issue 1), or formally scope R15 for AC5 to source imports and track Issue 1 separately. Then have a Verifier re-run the closure query.
- Issue 2 is cheapest to fix now, before features depend on the `ApiClientDIInitializer(backend: …)` signature.
