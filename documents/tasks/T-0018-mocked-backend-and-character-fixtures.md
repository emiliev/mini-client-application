# T-0018: `mc_mocked_backend` engine + `mc_fixtures_characters` / `mc_fixtures_media` (P1-06, P1-07)

| Field | Value |
|---|---|
| Status | Ready for verification |
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
- 2026-11-23: Engineer implemented all three packages. `tool/bazelw test` over the three package trees: 4 targets PASS (40 test cases); `build --config=lint //utility/...` clean; `dart format --set-exit-if-changed utility` clean. Finding F-0015 written.
- 2026-11-23: Code-review fixes (8 findings) with regression tests; F-0013 renumbered to F-0015. `--nocache_test_results` run: 4 targets PASS (48 PASS lines incl. regressions); lint and format clean.

## Outcome
Implemented:
- `utility/mc_mocked_backend`: `MockBackend` (seeded SplitMix64 with named forks, fixed clock, canonical sorted-key JSON), `MockBackendAdapter implements HttpClientAdapter`, `MockRouter` (`:param`, literal beats parameter), `LatencyProfile` (`none` / `realistic` / `slow`), `FailureRule` (`timeout`, `offline`, `http`, `notFound`, `unauthorized`, `malformed`, `slow`; triggers `always`, `once`, `times`, `afterCalls`, `probability`), scenarios, in-memory store, `reset()`, traffic stream plus a 500-entry ring buffer. No data.
- `utility/mc_fixtures_media`: 24 generated original placeholder portraits at 1x/2x/3x (288 KB total, `tool/generate_placeholders.dart`), `ApiImage` + `ImageVariant`, `BundledImageResolver` (`mock-asset://<set>/<id>`).
- `utility/mc_fixtures_characters`: 1,500 invented characters, `CharactersMockDomain` (`GET /v1/characters`, `GET /v1/characters/:id`), `characters.empty` and `characters.server_error` scenarios, `CONTRACT.md`, `fixtures/routes.json`, 7 provider snapshots (`tool/update_snapshots.dart`).

Deviations and choices to review:
- The plan lists `mc_prelude`, `mc_di`, `mc_config`, `mc_api_client` as deps of the engine; none exist yet (P1-05), so the engine depends on `dio` only. `NetworkDiagnostics` (an `mc_api_client` interface) is not defined here; `MockBackend` exposes the same surface (`setLatency`, `failNext`, `useScenario`, `traffic`) for P1-05 to adapt.
- `ApiImage` / `ImageVariant` live in `mc_fixtures_media` until `mc_media` exists (the plan has media depending on it). The JSON shape is the contract.
- `mc_fixtures_characters` depends on `mc_fixtures_media` (plan: engine only) so thumbnail paths are validated against the same placeholder catalogue.
- Failure rules run before route lookup, so a rule works on a path with no registered route.
- `TrafficEntry.duration` is the simulated time (latency plus injected delay), not wall time, so it is deterministic.
- Per-route latency overrides and `empty` as a generic failure kind are not built (the characters `empty` scenario is a handler override). Pending-work candidates.
- Contract schema validation (`contract/schemas/*.json`, plan 05) is not built; the snapshots plus a structural test stand in.
- Tests use `flutter_test` (F-0015 item 1) and add `fake_async` as a dev dependency; no new third-party package beyond `dio ^5.9.0` (and its transitive deps in `pubspec.lock`).
- Root-file changes: `pubspec.yaml` (3 workspace entries) and `pubspec.lock` (`dio 5.9.x` plus transitive `mime`, `typed_data`, `web` and others resolved by `fvm flutter pub get`). Not committed: `MODULE.bazel.lock` churn.
- `MODULE.bazel.lock` changed when Bazel resolved the new pub deps; it is not committed (TL re-resolves, per the task).

## AC to test map
| AC | Test (file, name contains the ID) | Result |
|---|---|---|
| T-0018-AC1 | `utility/mc_mocked_backend/test/mocked_backend_test.dart` `T-0018-AC1: seed 42 gives byte-identical responses on two backends` (+ 2 more) | PASS |
| T-0018-AC2 | same file, `T-0018-AC2: latency none ...`, `T-0018-AC2: realistic latency waits exactly the seeded delay` | PASS |
| T-0018-AC3 | same file, `T-0018-AC3: timeout once throws connectionTimeout, then succeeds` (+ 3 more) | PASS |
| T-0018-AC4 | same file, `T-0018-AC4: an unregistered route is 404 and names the path` (+ 2 more) | PASS |
| T-0018-AC5 | same file, `T-0018-AC5: the stream emits method, path, status and duration` (+ ring buffer) | PASS |
| T-0018-AC6 | `utility/mc_fixtures_characters/test/characters_test.dart` `T-0018-AC6: offset 30 limit 30 is page 2 of 1,500`, `...nameStartsWith=spi...` (+ 9 more) | PASS |
| T-0018-AC7 | `utility/mc_fixtures_characters/test/contract/provider_contract_test.dart` (7 snapshot tests, manifest, CONTRACT.md, `every ApiImage in all 1,500 responses resolves to an existing asset`); `utility/mc_fixtures_media/test/bundled_image_resolver_test.dart` | PASS |
| T-0018-AC8 | `tool/bazelw test //utility/mc_mocked_backend/... //utility/mc_fixtures_characters/... //utility/mc_fixtures_media/...` and `tool/bazelw build --config=lint //utility/...`; log in `documents/evidence/T-0018/engineer/ac8-test-and-lint.log` | PASS |

## Review fixes (all with regression tests)
| # | Finding | Fix | Test |
|---|---|---|---|
| 1 | Rule counting | Injected rules are checked first; only matching rules up to and including the winner are counted | `T-0018-AC3: a rule is consumed only by the request it fails` |
| 2 | Timeouts | A delay beyond `connectTimeout` / `receiveTimeout` waits that timeout, then throws `connectionTimeout` / `receiveTimeout` with the option's value; the injected `timeout` kind uses `connectTimeout` too | `T-0018-AC2: a delay beyond receiveTimeout or connectTimeout times out` |
| 3 | Malformed input | Bodies decode with `allowMalformed`; a bad URL (`%FF` in path or query) is a 400 `bad_request`, logged in traffic | `T-0018-AC4: bad UTF-8 bodies and bad percent-encoding answer 400 and are logged` |
| 4 | Strict numbers | `^\d+$` for ids, offset, limit and image ids | `T-0018-AC6: ids and paging values are strict decimal digits`, resolver test (AC7) |
| 5 | Cancellation | The delay races `cancelFuture`; cancel records `cancel` and skips the handler (traffic duration is zero) | `T-0018-AC5: cancelling during the delay records it and skips the handler` |
| 6 | `characters.empty` | Shares the list query validation | `T-0018-AC6: the empty scenario validates like the normal handler` |
| 7 | Router ties | `add` throws when two same-method routes can match one path with equal literal counts; more literals wins | `T-0018-AC4: ambiguous routes are rejected, literal precedence is kept` |
| 8 | Headers | List values join with `", "` | `T-0018-AC4: list-valued headers are joined with a comma and a space` |
