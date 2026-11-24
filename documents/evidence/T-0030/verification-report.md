# Verification report: T-0030, `mc_paging` and `mc_media` kits

- **Verifier:** crew: Verifier (Opus, a fresh agent, not the implementer)
- **Date:** 2026-11-25
- **Branch and commit verified:** `fleet/T-0030-paging-and-media` @ `63dbaf4` (detached, in the Verifier's own worktree)
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0030-verifier …`, shut down at the end
- **Simulator:** none. This is a utility-kit task: there is no e2e journey and no UI checkpoint (ADR-0006 L4 and L5 don't apply).
- **Verdict:** **PASS** on every AC (AC1 to AC7). There are no blockers or majors; the minor gaps are listed under Issues found.

Supporting evidence is in [`verifier/`](verifier/):
- [`AC7_closure.md`](verifier/AC7_closure.md)
- [`AC7_negative_control_paging.md`](verifier/AC7_negative_control_paging.md)
- [`AC7_negative_control_media.md`](verifier/AC7_negative_control_media.md)
- [`coverage.md`](verifier/coverage.md) and [`cov.py.txt`](verifier/cov.py.txt)
- [`mutations.md`](verifier/mutations.md)
- [`verifier_probe_test.dart.txt`](verifier/verifier_probe_test.dart.txt): the edge-case probes, run as a temporary `dart_test` and removed afterwards

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Tests | `test //...`, then `test --nocache_test_results //...`, because the first run was all disk-cache hits | **58 / 58 pass**, executed fresh (`Executed 58 out of 58 tests: 58 tests pass.`) |
| Lint (analyze and format aspects) | `build --config=lint //...` | `Build completed successfully` |
| Architecture | `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Rules fork | `tool/rules_fork.sh check` | `ai_rules_dart: 2 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Format | `fvm dart format --output=none --set-exit-if-changed utility/mc_paging utility/mc_media utility/mc_fixtures_media` (after `fvm dart pub get`, which left the tree unchanged) | `24 files (0 changed)`. Repo-wide, only `tool/loc/**` (4 files) would change; that code predates this task and is outside the workspace. |
| AC7 closure | `MC_OUTPUT_BASE=… tool/checks/T-0030-AC7_closure.sh` | `PASS`: `mc_paging` has 2918 targets and no markers; pure `mc_media` has 1107 targets and no markers; the positive control `mc_media_scope` shows `pub_deps__flutter` |
| Coverage, ADR-0010 (≥ 90 % per package) | `coverage --nocache_test_results` over the 6 unit targets, then the Verifier's own LCOV parser | **`mc_paging` 98/98 = 100 %**, **`mc_media` 21/21 = 100 %** |
| Flakiness of the real-`Timer` test | `test --nocache_test_results --runs_per_test=20 //utility/mc_paging:debounced_query_test` | 20 / 20 pass (max 0.2 s, dev 0.0 s) |

## Acceptance criteria
| AC | Scenario (short) | Mapped tests | Does the test really assert the AC? | Result |
|---|---|---|---|---|
| T-0030-AC1 | 45 items, limit 20: loadFirst, then loadMore ×2 → offsets 0/20/40, 45 in order, end | `paging_controller_test` group "T-0030-AC1 loading pages"; `paged_state_test` | **Yes.** It asserts the exact offsets `[0, 20, 40]`, limits `[20, 20, 20]`, `items == 0..44`, `hasReachedEnd`, `total == 45`, no failure. Killed by mutations: the end check off by one (`>=`→`>`) and duplicated items. | **PASS** |
| T-0030-AC2 | No request at the end; no second request while one is in flight | `paging_controller_test` "T-0030-AC2 guards" and "stale responses" | **Yes.** It counts the requests after `hasReachedEnd`, and it gates the fetcher with a `Completer` and calls `loadMore` twice. Killed by mutations: removing the end check, the in-flight check, or the stale-generation check. | **PASS** |
| T-0030-AC3 | A failing page 2 keeps page 1 and exposes the failure; retry requests only that page and appends once | `paging_controller_test` "T-0030-AC3 failures" | **Yes.** It asserts `items == 0..19` plus `ApiServer`, then requests `[0, 20, 20]` and `items == 0..39` exactly (any duplicate fails). Killed by mutations: retry asks for page 1; retry asks for page 1 and appends (no de-dup); retry ignores `replace`; `loadMore` is not blocked after a failure; the `try/catch` around the fetcher is removed. | **PASS** |
| T-0030-AC4 | 300 ms debounce on a fake clock: 5 characters in 200 ms → 1 search with the final text; blank after non-empty → clear | `debounced_query_test` | **Yes.** An injected `TimerFactory` with a hand-advanced fake clock fires `['thor!']` once; the test checks for nothing at 299 ms and a fire at 300 ms; it covers clear, cancelling a pending search on clear, trim, and dispose. Killed by mutations: no cancel on update, blank treated as a search, `dispose` does nothing, no trim. Probes: a keystroke after a fire opens a new window (`['a', 'ab']`), and two clears in a row emit one clear. One test uses a real 1 ms `Timer` (see minor issue 1). | **PASS** |
| T-0030-AC5 | Cap 10; de-duplicated; most recent first; survives a new instance | `search_history_test` (temp-dir `FileStore`) | **Yes.** It covers the move-to-front de-dup, 12 → the 10 most recent in order, a new `SearchHistory` *and* a new `FileStore` on the same directory, overlapping adds, the wrong shape, and a corrupt file. Killed by mutations: no de-dup, no cap, append at the end, adds not serialised. Probes: 15 concurrent adds on one instance are all kept and capped correctly. Corrupt file: `load` and `add` fail until `clear()`, then it recovers. Two instances on one store lose updates (minor issue 2). | **PASS** |
| T-0030-AC6 | `of` returns the resolver; no scope → a `FlutterError` naming `McMediaScope`; `BundledImageResolver` is an `McImageResolver`; dependents unchanged and green | `media_scope_test`, `api_image_test`, `mc_fixtures_media:media_contract_test` | **Yes.** It checks `same(resolver)`, `isA<FlutterError>()` with the message containing `McMediaScope`, and `updateShouldNotify`, via the rebuild count. Killed by mutations: throwing `StateError`, a message that doesn't name the scope, notify always true. `git diff origin/main...HEAD` over `mc_fixtures_characters/`, `mc_api_client/` and `mc_fixtures_media/test/bundled_image_resolver_test.dart` is **empty**. `bazel query rdeps` lists `mc_fixtures_characters:{characters_test, provider_contract_test}`, `mc_api_client:api_client_test` and `mc_fixtures_media:bundled_image_resolver_test`; all pass in the uncached run. | **PASS** |
| T-0030-AC7 | Workspace, BUILD shape, arch check, pure closure, ≥ 90 %, gates | `mc_paging:purity_test`, `mc_media:purity_test`, `tool/checks/T-0030-AC7_closure.sh`, gates | **Yes.** Root `pubspec.yaml` lists `utility/mc_media` and `utility/mc_paging`. The BUILD files follow the `mc_api_errors` / `mc_bloc_kit` shape, and the analyze and format aspects run on the new targets: a mis-formatted probe test failed `DartFormat` under `test`. The closure check fails when it should (see the negative controls below). The purity tests go red on a hand-written `mixin` and on a `package:flutter` import. The only mixin is freezed's generated `_$PagedState`, which the TL accepted. | **PASS** |

### Negative controls for the AC7 closure check (the Verifier's own)
- **A:** `//utility/mc_media:mc_media_scope` added to `mc_paging`'s `_DEPS`. The script exits 1: `mc_paging` has 4078 targets and shows `pub_deps__flutter//:flutter`; result `FAIL T-0030-AC7`.
- **B:** `@pub_deps//:flutter` added to the pure `//utility/mc_media:mc_media`. The script exits 1: 2298 targets, `pub_deps__flutter//:flutter`; result `FAIL T-0030-AC7`.
- **Independent check:** a manual `cquery deps(...)` shows that the only `flutter_darwin-arm64` targets in either pure closure are `dart-sdk/**` and the Dart toolchain. There is no `packages/flutter` and no `sky_engine` (0 hits). The script's floor of 100 targets makes an empty or failed query FAIL.

### Barrel surface and `mc_arch_check` with two barrels
- `mc_paging.dart` uses `show` for each export: `Page`, `PageRequest`, `PagedState`, `PageFetcher`, `PagingController`, `DebouncedQuery`, `TimerFactory` (the type of a public constructor parameter), and `SearchHistory`.
- `mc_media.dart` exports `ApiImage`, `ImageVariant`, `McImageResolver` and `ResolvedImage`. `mc_media_scope.dart` exports `McMediaScope`. `mc_fixtures_media` re-exports `mc_media` with `show ApiImage, ImageVariant`. Nothing extra is exported.
- Probe: three `package:mc_media/src/...` imports were added, from `mc_fixtures_media/lib/src/bundled_image_resolver.dart` (`src/api_image.dart`, `src/media_scope.dart`) and from `mc_paging/lib/src/page.dart` (`src/image_resolver.dart`). `mc_arch_check` reported `[barrel-only] … imports package:mc_media/src/…` for each one and exited 1. **Barrel-only enforcement still holds with two barrels.**

### Edge-case probes (paging), all behaved correctly
- A `refresh` while a `loadMore` is in flight:
  - **Stale page 2 lands last:** it is dropped. The items are `0..19` and the next `loadMore` requests offset 20.
  - **Stale page 2 lands first:** it is dropped, and `isLoadingMore` stays true until the refresh lands. A `loadMore` in between makes no request.
- **A stale *failure* after `refresh`:** it is dropped, and `retry` has nothing to replay.
- **Two overlapping refreshes:** the older response, which lands last, is ignored.
- **`total` changes between pages:**
  - It shrinks from 45 to 30: the list ends at 30.
  - It grows from 25 to 60: the list continues to 60, with offsets `[0, 20, 40]`.
  - A short page whose `total` claims more continues, and the next empty page ends the list.
- **A fetcher that throws:** a synchronous throw becomes `ApiUnexpected(StateError…)` and `retry` recovers. A thrown `Error` becomes `ApiUnexpected(ArgumentError…)`. `isLoadingMore` is reset in both cases.
- **`limit: 0` or negative:** an `AssertionError` in debug. `PageRequest(offset: -1)` is accepted without validation (issue 5).

## Mutation checks ([diffs](verifier/mutations.md); every mutation was restored, and the tree is clean)
| # | Mutation | Killed by |
|---|---|---|
| m1 | remove the end guard (`hasReachedEnd`) in `loadMore` | AC2 "loadMore at the end makes no request" |
| m2 | remove the in-flight guard | AC2 "loadMore while one is in flight…" (`[0, 20]` expected) |
| m3 | `retry` re-requests page 1 (replace) | AC3 "retry requests only the failed page…" (`[0, 20, 20]`) |
| m4 | `retry` re-requests from offset 0 and **appends** (no de-dup) | AC3 "retry … appends once", AC3 "failing refresh … retry replaces" |
| m4b | duplicated items with an unchanged request sequence | 5 tests (AC1, AC2, AC3 item-list assertions) |
| m5 | remove the stale-generation check | AC2 "a response from before loadFirst is dropped" |
| m6 | remove the "blocked after failure" guard | AC3 "loadMore after a failure waits for retry" |
| m7 | end check `>=` → `>` | AC1 main test, AC2 end test |
| m8 | `retry` ignores `replace` | AC3 "failing refresh … retry replaces them" |
| m9 | remove the `try/catch` around the fetcher | AC3 "a fetcher that throws becomes an ApiFailure" |
| d1–d4 | debounce: no cancel / blank is a search / dispose does nothing / no trim | AC4 (1 to 3 tests each) |
| h1–h4 | history: no de-dup / no cap / append at the end / adds not serialised | AC5 (1 to 5 tests each) |
| s1–s3 | scope: `StateError` instead of `FlutterError` / message doesn't name the scope / notify always true | AC6 media_scope_test |
| p1–p2 | a hand-written `mixin` in `mc_paging` / a Flutter import in the pure `mc_media` | AC7 purity tests |

All 23 mutations were killed. None survived.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none.
  - `git diff origin/main...HEAD` removes no `test(` or `expect(` lines.
  - No `skip:` or `solo:` was added.
  - The test files of the existing dependents are byte-identical to `origin/main`.
  - `api_image.dart` was moved from `mc_fixtures_media` (R092) with only a comment change.
- **Lint suppressions added:** none. The diff adds no `// ignore` or `ignore_for_file`.
- **Golden files updated:** none.
- **Every AC has a test whose name contains `T-0030-ACn`:** AC1 9, AC2 10, AC3 8, AC4 8, AC5 8, AC6 9, AC7 2 (counted from occurrences of the ID).
- **Scope of the diff:** 42 files, all within T-0030:
  - the two new packages
  - `mc_fixtures_media`: `implements`, `@override`, the re-export, and one new test
  - two lines in the root `pubspec.yaml`
  - one check script
  - F-0029
  - the engineer's own task file and evidence

  Nothing unrelated changed. The engineer didn't touch `STATUS.md`, `BOARD.md`, the journal or any index. `pubspec.lock` and `MODULE.bazel.lock` are unchanged, and `pub get` resolves without changes.

## TL decisions: implementation matches
- `mc_media` is a pure `dart_library :mc_media` (barrel `mc_media.dart`) plus a `flutter_library :mc_media_scope` (barrel `mc_media_scope.dart`), both with `package_name = "mc_media"`.
- `ResolvedImage` has only `variant` and no `ImageProvider`.
- `mc_paging` has no `mc_bloc_kit` dependency in BUILD or in pubspec; it uses the `onState` callback.
- `PageFetcher<T> = Future<Result<Page<T>, ApiFailure>> Function(PageRequest)`.
- No hand-written mixins. freezed's `mixin _$PagedState` is generated.

## Issues found (none blocking)
1. **(minor)** `utility/mc_paging/test/debounced_query_test.dart:138-149`: "the default timer is a real Timer" runs a real 1 ms `Timer`. The task says "No real timers in tests".
   - **Impact:** it isn't flaky. It passed 20 out of 20, it makes no timing assertion and it only awaits the completer. The engineer disclosed it in the handoff.
   - **Fix:** cover the default factory without real time: run the test inside `runZoned(..., zoneSpecification: ZoneSpecification(createTimer: …))`, or use `fake_async`, which is already in the lock as a transitive dependency.
2. **(minor)** `utility/mc_paging/lib/src/query/search_history.dart:14-28`: adds are serialised only within one instance (`_tail`).
   - **Repro:** two `SearchHistory` objects on the *same* `FileStore` and key lose updates. With `Future.wait([a.add('x'), b.add('y'), a.add('z'), b.add('w')])` the result is `[w, y]`. With two `FileStore`s on one directory it is `[z, y]`. See the probe "two SearchHistory on ONE FileStore".
   - **Impact:** not required by AC5. It matters if features build one history per bloc.
   - **Fix:** document "one instance per key" (DI singleton), or serialise per store and key.
3. **(minor)** `search_history.dart:18-19, 33-34`: a corrupt store file makes `load` *and every `add`* fail until someone calls `clear()`. This is tested and documented ("a failed read is a failure"). Nothing heals it on its own, so the P1-12 or feature UI must handle that failure by clearing.
4. **(minor)** `search_history.dart:18-19, 47-48`: `load` doesn't apply `cap`. A stored list longer than the cap is returned whole until the next `add`. Repro: 15 stored entries, `cap: 10`, then `load` returns 15.
5. **(minor)** Lifecycle and validation:
   - `paging_controller.dart:64-84`: after `dispose()`, `loadMore`, `refresh` and `retry` still call the fetcher (2 requests in the probe); only emission is suppressed.
   - `debounced_query.dart:32-54`: `update` after `dispose()` schedules a new timer and will call `onSearch`.
   - `page.dart:3`: `PageRequest` accepts a negative offset.
   - `paging_controller.dart:25`: `limit > 0` is only an `assert`. With `limit: 0` in release, the list ends after the first page, because an empty page ends it, so there is no infinite loop.
6. **(info)** `tool/mc_arch_check/lib/src/arch_check.dart:251`: the barrel-only message always suggests `package:<name>/<name>.dart`, so it doesn't mention `mc_media_scope.dart`. The check treats any top-level `lib/*.dart` as importable, which is exactly what two barrels need.
7. **(info)** `utility/mc_media/test/purity_test.dart:10-14` hard-codes the three pure files. A new file in the pure library would not be scanned, but the closure check would still catch a Flutter dependency.
8. **(info)** Under `bazel coverage`, every `purity_test` and `no_flutter_test` takes about 110 s, including the existing `mc_api_errors:no_flutter_test`. This is a coverage-mode quirk that predates the task; under `test` they take 0.2 to 0.8 s.
9. **(info)** The branch is behind `origin/main`, which has the T-0029 merge and the T-0031 docs. `git merge-tree --write-tree origin/main HEAD` is clean, with no conflicts. The TL re-runs the gates on the merge result per ADR-0004.

## Notes for the Tech Lead
- Every gate was re-run on a fresh output base with `--nocache_test_results`. The first `test //...` was served entirely from the shared disk cache, so it proves nothing by itself.
- Issues 2 to 5 are good inputs for P1-12 and `characters_list`, when the bloc wiring and the search UI land. None of them breaks an AC.
