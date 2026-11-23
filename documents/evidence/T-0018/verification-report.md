# Verification report: T-0018: `mc_mocked_backend` + `mc_fixtures_characters` / `mc_fixtures_media`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0018-mocked-backend` @ **`8a93613`** (re-verification; see the section after this header). First pass: `ce92366`. See "Commit note": the dispatch named `9bbcd3f`, and the code is identical in both.
- **Simulator:** none. This task has no UI and no e2e, and Android is deferred (Q-009).
- **Bazel:** my own output base, `/private/tmp/claude-501/mc-T0018-verifier-ob`, through `tool/bazelw`. I shut the server down at the end.
- **Verdict:** **PASS** (first pass at `ce92366`, re-verification at `8a93613`)

## Re-verification at `8a93613` (2026-11-23)
`8a93613` is `ce92366` plus `1357160` (8 code-review fixes) and `8a93613` (the 4 low items from the first pass). I read the full diff and re-ran everything with my own output base.

| Gate | Result |
|---|---|
| `test --nocache_test_results` over the 3 package trees | PASS: 4 of 4 targets, with 21 + 13 + 12 + 4 = **50 cases** |
| `build --config=lint //utility/...` | PASS, clean |
| Verifier black-box test (11 first-pass checks + 6 new ones for the fixes) | PASS: **17 of 17** |
| Mutations on the new code | All caught (see below) |

**Review fixes**
| # | Fix | What I checked | Result |
|---|---|---|---|
| 1 | Rule counting: injected rules first, only the winner counts | Code: `_pickFailure` returns on the first rule that fires, and later rules are not touched. Black-box: configured `always http(500)` plus `failNext(timeout)` gives a timeout, then a 500. A configured `once timeout` shadowed by `failNext(503)` gives 503, then the timeout, then 200. Mutation: putting `_configured` back first failed the Engineer's regression test and my test. | PASS |
| 2 | Dio connect / receive timeouts honoured | Engineer's `fake_async` test: the request is not done at 299 ms and throws `receiveTimeout` at 300 ms, and the traffic entry records the timeout's duration. Black-box (real time, `BaseOptions`): 400 ms latency with `connectTimeout` 30 ms gives `connectionTimeout` in under 300 ms; with `receiveTimeout` 30 ms it gives `receiveTimeout`; with 2 s it gives 200. All three appear in traffic. | PASS |
| 3 | Malformed input gives a logged 400 | Black-box: `/v1/characters/%FF` and `?nameStartsWith=%FF` are 400, and both are in traffic. Note: a malformed **body** is not a 400. It decodes with `allowMalformed` and reaches the handler as text, giving 200, which the Engineer's test asserts. Only a bad URL is a 400. The test name "bad UTF-8 bodies ... answer 400" is misleading (info). | PASS |
| 4 | Strict `^\d+$` for ids, offset, limit and image ids | Black-box: `offset=1.0`, `-0`, `limit=0x1F`, `+30` and a 23-digit limit are 400. Ids `1e5`, `0x186A0`, `-100000`, `+100000` are 404. Image ids `1e1`, `0x1`, `+1` are rejected. Mutation: regex `.*` failed 2 of the Engineer's tests and my test. | PASS |
| 5 | Cancellation races the delay and skips the handler | Black-box with a real Dio `CancelToken`: 300 ms latency, cancel at 20 ms. It throws `DioExceptionType.cancel`; 400 ms later the handler counter is still 0, and the traffic entry is `cancel`. | PASS |
| 6 | `characters.empty` validates | Black-box: `limit=0` under the scenario is 400 `invalid_parameter`, and `limit=5` gives `total: 0`. | PASS |
| 7 | Router tie throws | Black-box: `GET /v1/:a` then `GET /v1/:b` throws `StateError`. `POST /v1/:b` and the literal `GET /v1/lit` are accepted. | PASS |
| 8 | List headers joined | Engineer's test: `['a','b']` arrives as `"a, b"`. I read the code and agree. | PASS |

**First-pass low items**
| Item | Result |
|---|---|
| 1: `spi` count | `CONTRACT.md` now says 152, and the new `provider_contract_test` case parses the number out of `CONTRACT.md` and compares it with the live `total`, so the doc can't drift. **PASS** |
| 2: seeded-RNG determinism | New `T-0018-AC1: RNG-driven bodies and latency repeat for a seed and differ across seeds`. The `/v1/random` echo route draws from `SplitMix64(seed)`. Bodies and latencies are equal for seed 42 on two instances and differ for seed 43. **PASS** |
| 3: `dio` as a dev dep | Moved to `dev_dependencies` in `mc_fixtures_characters/pubspec.yaml`. `lib/` still doesn't import it. **PASS** |
| 4: two-rules case | Covered by fix 1, through both the Engineer's regression test and mine. **PASS** |

**Residual observations (info, not blocking)**
- A rule is picked, and its count used up, before the delay. So a request that then ends in a Dio timeout or a cancel still uses up a `once` rule. This is defensible (the request did "happen"), but P5 may want to document it.
- Hygiene is unchanged: the new commits touch only the three packages, the task file, the renamed finding (F-0013 -> F-0015) and engineer evidence. There are no root-file changes and no generated files. Bazel again rewrites `MODULE.bazel.lock` locally with the dio entries; I reverted it, and the TL re-resolves it at merge.

---
*First-pass report at `ce92366` follows; it is kept as is.*

## Commit note
The dispatch named `9bbcd3f`, but the branch head is `ce92366`. Both commits have the same message and author time. Their only difference is `MODULE.bazel.lock`: `9bbcd3f` committed the lock that Bazel re-resolved, and `ce92366` puts back the base (`e18ade6`) lock. That matches the task, which says the TL re-resolves the lock at merge. When I ran `tool/bazelw` on `ce92366`, Bazel rewrote the lock to exactly the `9bbcd3f` content. That diff has 841 lines added and 166 removed, and it contains only the new `pubspec.lock` hash and the dio-related pub repos (`dio`, `dio_web_adapter`, `http_parser`, `mime`, `typed_data`, `web`, plus their `scc_targets`). I reverted it afterwards. Every source file verified here is the same in both commits.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Tests (AC8) | `tool/bazelw --output_base=… test --nocache_test_results //utility/mc_mocked_backend/... //utility/mc_fixtures_characters/... //utility/mc_fixtures_media/...` | PASS: 4 of 4 targets, with 14 + 11 + 11 + 4 = 40 cases |
| Lint (AC8) | `tool/bazelw --output_base=… build --config=lint //utility/...` | PASS: 8 targets, clean |
| Format | covered by the lint aspect, which runs `dart format` on every target (it failed on my own unformatted test, so it is live) | PASS |
| Verifier black-box | `documents/evidence/T-0018/verifier/verifier_blackbox_test.dart`, run as a temporary `flutter_test` target in `//utility/mc_fixtures_characters` (removed afterwards, not committed) | PASS: 11 of 11 |
| Mutation check | 3 mutations (described below), applied and then reverted | Every mutation was caught |
| Coverage | not measured (no coverage gate is wired for Bazel yet) | n/a |
| L4 E2E | n/a (no UI) | n/a |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) | Does the test really assert the AC? | Result |
|---|---|---|---|---|
| T-0018-AC1 | Seed 42 on two instances gives byte-identical responses | `mocked_backend_test.dart` `T-0018-AC1: seed 42 gives byte-identical…`, sorted-keys/fixed-clock, SplitMix64 forks; `characters_test.dart` "a second backend with the same seed pages identically" | Yes, but weakly on the engine side. The echo domain draws nothing from the PRNG, so the byte comparison there proves sorted keys and a fixed clock, not seeded data. The characters test covers seeded data. My black-box test runs 9 requests over the characters domain (list, search, `-modified` order, detail, 404, 400, unknown route) on two instances. The bytes are identical, also under realistic latency. With seed 43 the data responses differ and the error bodies stay the same. | PASS |
| T-0018-AC2 | Latency `none` under `fake_async` adds no time; `realistic` waits exactly the seeded delay | `T-0018-AC2: latency none…`, `T-0018-AC2: realistic latency waits exactly…` | Yes. The first test asserts `elapsed == 0`, no pending timers, and that `handle()` completes on microtasks alone. The second asserts the request is not done at `delay − 1 µs` and is done at `delay`, and that a fresh instance gets the same delay. My black-box test adds that the delays for 10 requests are equal across instances and differ across seeds. | PASS |
| T-0018-AC3 | `FailureRule(GET /v1/x, timeout, once)`: call 1 throws `connectionTimeout`, call 2 succeeds | `T-0018-AC3: timeout once throws connectionTimeout, then succeeds` (+ 3 more) | Yes. It checks the `DioException.type` and that the next call returns 200. My black-box test sends a non-matching `GET /v1/y` and a non-matching `POST /v1/x` first, which don't consume the rule, then 6 calls: exactly 1 timeout (on call 1) and 5 × 200. After `reset()` the rule fires exactly once again, and `failNext` fires once. The mutation `call <= n + 1` failed 2 of the Engineer's AC3 tests. | PASS |
| T-0018-AC4 | An unregistered route returns 404 with a body naming the path | `T-0018-AC4: an unregistered route is 404 and names the path` (+ 2) | Yes. It asserts the status, that `error.message` contains the path, and `error.path`. | PASS |
| T-0018-AC5 | The diagnostics stream emits method, path, status and duration | `T-0018-AC5: the stream emits…`, ring buffer | Yes. It asserts all four fields for 200, 404 and timeout entries, plus the error name and the ring-buffer cap. The plan's `NetworkDiagnostics.traffic` is `MockBackend.traffic` for now (an accepted deviation). | PASS |
| T-0018-AC6 | `offset=30&limit=30` is page 2 of 1,500 in stable order; `nameStartsWith=spi` is case-insensitive | `characters_test.dart` (11 cases) | Yes. Page 2 equals items 30 to 59 of a 60-item page. A full walk over all 1,500 shows strict name order and no duplicates. The search is tested as `spi`, `SPI` and `Spi`. My black-box test checks that `offset=0` equals no offset, the default limit is 20, `offset=1470` gives 30 results, `1499` gives 1, and `1500`, `1501`, `5000` and `999999` give 0 with `total` 1500. It re-sorts the concatenated pages independently, and page 2 matches. For `spi` / `SPI` / `Spi` / `sPi` / `sPI` it checks the exact id set {i : i mod 40 < 4}, 152 ids worked out from the documented formula, and that every case variant gives the same page. `spi` at offset 150 gives 2, and `spa` gives 38. Dropping `toLowerCase` failed 2 of the Engineer's tests. | PASS |
| T-0018-AC7 | Responses match the provider contract snapshots; every `ApiImage` resolves to a bundled asset | `provider_contract_test.dart` (7 snapshots, manifest, CONTRACT.md, all 1,501 images), `bundled_image_resolver_test.dart` (4) | Yes. The snapshots are generated by `tool/update_snapshots.dart`, which is normal for snapshots, but they are checked-in files that the test reads and compares. Editing `"total": 152` to `150` in `list_search_spi.json` made the test fail. I checked them against an independent derivation (id = 100000 + title × 40 + alias): first page `[100486, 101406, 101446]` (Amber + Alchemist/Artisan/Bard), detail `100000` = Spindle Warden, `-name` gives `[100229, 101389]`, and `spi` total 152. These match. Assets: all 72 files are valid PNGs at 60×90 (1x), 120×180 (2x) and 180×270 (3x). The asset key from a real `/v1/characters/100000` response loads through `rootBundle` in a `flutter_test`, and a key that isn't bundled (`999.png`) fails, as a negative control. So the asset is in the Flutter bundle, not just on disk. | PASS |
| T-0018-AC8 | The Bazel tests pass and `build --config=lint` is clean | the gate rows above | Re-run by me with `--nocache_test_results` | PASS |

## Conformance
- **R3 (data-free engine):** PASS. `mc_mocked_backend/lib` holds no data. The only domain words are in doc comments (`/v1/characters` as an example path). Data, handlers, the manifest and `CONTRACT.md` are in `mc_fixtures_characters`.
- **Original content (ADR-0005 §5, R-005):** PASS as far as I can tell. Names are `<alias> <title>` built from two lists of 40 generic English words. A grep for common Marvel names (Spider, Hulk, Stark, Avenger, Loki, and others) finds nothing. Descriptions, powers, teams and origins are invented filler. The images are generated gradients with a plain silhouette (I looked at `3.0x/017.png`), made by `tool/generate_placeholders.dart`.
- **D5 / plan §5 (Dio `HttpClientAdapter`):** PASS. `MockBackendAdapter implements HttpClientAdapter` returns `ResponseBody.fromString(json, status)`. Timeout and offline throw `DioException.connectionTimeout` / `connectionError`. The app-side wiring (`MockedBackendDIInitializer`) is out of scope.
- **Deviations judged:**
  - No `NetworkDiagnostics`: **accepted**. Its home, `mc_api_client` (P1-05), doesn't exist yet. `MockBackend` exposes the same surface (`setLatency`, `failNext`, `useScenario`, `traffic`, a 500-entry ring buffer), so P1-05 only has to add `implements`.
  - `ApiImage` in `mc_fixtures_media`: **accepted as interim**. `mc_media` doesn't exist yet, and the JSON shape is the contract. This needs a follow-up move when `mc_media` lands; I recommend a pending-work entry.
  - `flutter_test` instead of `test`: **accepted**. `package:test` isn't in the root lock, and adding it is a root-lock decision for P3/P5 (F-0013 §1). `fake_async` was already in the lock (it comes in through `flutter_test`).
  - The pipeline runs failure rules → latency → route → handler, where the plan says route → scenario → failures → latency. **Accepted** and disclosed. It lets a rule fail a route that has no handler.
  - `mc_fixtures_characters` depends on `mc_fixtures_media`: accepted, since it validates thumbnails against the real catalogue.

## Hygiene
- Images: 72 PNGs, 128,890 bytes in all (largest 2.8 KB, none over 8 KB). The Outcome's "288 KB" is the `du` block count, not the byte size.
- No generated files, `bazel-*`, `.dart_tool` or `build/` in the diff.
- Root changes: `pubspec.yaml` adds only the 3 `workspace:` entries. `pubspec.lock` adds only dio 5.11.1 and its transitive deps (`dio_web_adapter`, `http_parser`, `mime`, `typed_data`, `web`), and the SDK floor `flutter: ">=3.47.7 <4.0.0"` follows from the packages' constraint. `MODULE.bazel.lock` is unchanged at `ce92366`.
- Docs: the crew touched only its own task file, the new finding F-0013 and its engineer evidence. No index, STATUS or BOARD files were edited.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (all files are new).
- Lint suppressions added: none (`grep ignore:` finds nothing in the three packages).
- Golden files updated: none.

## Issues found (none block the verdict)
1. **(low, doc)** `CONTRACT.md` "Test-facing facts" says `nameStartsWith=spi` matches **150** characters. The real count is **152** (4 aliases × 38 titles, because 1,500 = 37 × 40 + 20), and the checked-in `list_search_spi.json` snapshot itself says `"total": 152`. Repro: `GET /v1/characters?nameStartsWith=spi` returns `total: 152`. Fix: change the number in `CONTRACT.md`.
2. **(low, test strength)** The engine's AC1 byte-identity test uses an echo domain that draws nothing from the PRNG, so on its own it can't catch a seeding regression in the engine's data path. The characters-level same-seed check and the Verifier's black-box test cover it. Suggestion: add a seeded value, for example `SplitMix64(context.seed).fork('x').nextInt64()`, to the echo body, or move to the plan's digest-of-every-response `determinism_test`.
3. **(low, semantics)** `MockBackend.handle` adds 1 to `calls` for **every** matching rule, even after an earlier rule has already fired. So when two rules match, a shadowed `once` / `times(n)` rule is used up without ever firing. Example: a scenario rule `always http(500)` plus `failNext(timeout)` on the same path. The `failNext` is used up silently and the timeout never happens. Suggestion: count only the rule that fires (or document the precedence) before P5 builds BDD steps on `failNext`.
4. **(low, hygiene)** `mc_fixtures_characters/pubspec.yaml` lists `dio` under `dependencies`, but only its tests import it (`lib/` doesn't, and the `dart_library` BUILD deps leave it out). It belongs in `dev_dependencies`.
5. **(info)** The dispatch said `9bbcd3f`, but the branch head is `ce92366`; see the commit note above. The TL should merge `ce92366` and re-resolve `MODULE.bazel.lock` as planned. I expect the re-resolved lock to equal `9bbcd3f`'s.

## Notes for the Tech Lead
- Pending-work candidates: move `ApiImage` / `ImageVariant` into `mc_media` once it exists; per-route latency overrides; `empty` as a generic `FailureKind`; contract JSON schemas (plan 05); `package:test` in the root lock (F-0013 §1); and issues 2 to 4 above.
- `Uri.decodeComponent` on a path parameter is called outside the handler `try`. A malformed `%` escape in a path would raise a Dart error instead of a 4xx response. That edge case only matters if callers build paths by hand; Retrofit encodes paths properly.
