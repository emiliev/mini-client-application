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

---

## Re-verification at b8d3abe

- **Verifier:** the same fresh Verifier agent (not the implementer). Detached at `b8d3abe` in its own worktree, output base `/tmp/mc-ob-T-0030-verifier`.
- **Commits since 350e215:**
  - `f10c257` and `b53b963`: the fix round
  - `f5c6ca5`: a merge of `origin/main` (`c14706e`)
  - `b8d3abe`: refreshed evidence
- **Verdict:** **PASS** on every AC. All 14 fix items are confirmed. There are no new blockers or majors; the five minor items and two info notes below don't break any AC.

Evidence (`verifier/`):
- [`reverify_new_tests_on_prefix_lib.txt`](verifier/reverify_new_tests_on_prefix_lib.txt)
- [`reverify_mutations.md`](verifier/reverify_mutations.md)
- [`reverify_probe_test.dart.txt`](verifier/reverify_probe_test.dart.txt)
- [`reverify_AC7_closure.md`](verifier/reverify_AC7_closure.md)
- [`reverify_AC7_negative_control_media.md`](verifier/reverify_AC7_negative_control_media.md)

### Do the new tests fail on the pre-fix lib sources from 350e215?
Method: restore one pre-fix `lib` file from `350e215` (`git show 350e215:<file>`), keep the new tests, and run the target with `test --nocache_test_results`. The new `page.dart` stays in place, so the test still compiles against `PageRequest.checked`. Afterwards, restore the file from HEAD.

| Pre-fix file restored | New tests that FAIL (my run) |
|---|---|
| `paging_controller.dart` | "every entry point does nothing after dispose"; "an Error from the fetcher propagates and frees the controller"; "later changes to the fetcher list do not change the state"; "a limit of zero or less is an ArgumentError" |
| `query/debounced_query.dart` | "an unchanged trimmed query does not search again"; "deleting text while a search is pending cancels it, no clear"; "update after dispose does nothing" |
| `query/search_history.dart` | "a corrupt file loads as empty and add heals it"; "clear that is not awaited runs after earlier adds"; "load applies the cap to an oversized stored list" |

This matches the engineer's `fixround-tests-fail-without-fix.txt`, including the clear-ordering test that the file's note mentions. Two tests pass on the old code by design, because they pin behaviour that already existed:
- "a stale response does not clear the newer in-flight flag"
- "add after clear starts a fresh history"

I pinned both with mutations instead (see the table below).

### The 14 items
| # | Item | Check | Result |
|---|---|---|---|
| 1 | `clear` runs through `_tail` | `search_history.dart:36-43` uses `_enqueue` for both `add` and `clear`. The test fails on the pre-fix code. Mutation k1 (clear outside the queue) is killed by 2 tests. | **OK** |
| 2 | A corrupt store loads as empty and `add` heals it | `load` returns `success(read.fold(_decode, (_) => []))`. The test checks that `add('x')` returns `['x']` and that a new instance reads `['x']`. Fails on the pre-fix code; mutation k3 is killed. Probe: a *directory* in place of the file loads as `[]`, and `add` then returns a failure, because the write fails. That is acceptable. | **OK** |
| 3 | `load` applies the cap | `_decode` calls `.take(cap)`. The test fails on the pre-fix code; mutation k2 is killed. | **OK** (see minor R4) |
| 4 | One instance per key is documented | `search_history.dart:7-9`: "Use one instance per store key … one can overwrite the other's update (accepted)." | **OK** |
| 5 | Disposed: every entry point is a no-op; only the generation-matched run clears `_inFlight` | `_disposed` guards at `:52`, `:65`, `:76` and `:88`. The test fails on the pre-fix code. Mutations r4a (`loadFirst`), r4b (`refresh`) and r4d (`retry`) are killed. **r4c (`loadMore`) survives**, because the test's `loadMore` is already blocked by the failure guard; the probe confirms the real code is guarded. Mutation r1 (clearing `_inFlight` before the generation check) is killed. **r2 (the Error path clears `_inFlight` regardless of generation) survives**; the probe confirms the real code is correct. | **OK** (test gaps R2, R3) |
| 6 | Only an `Exception` becomes an `ApiFailure`; an `Error` propagates and the controller stays usable | `on Exception catch` / `on Object { … rethrow; }` at `:107-118`. The test fails on the pre-fix code; mutation r3 (`on Object catch`) is killed. A `FormatException` still maps (the original m9, re-run, is killed). Probe: after an `Error`, the next `loadMore` works, so the controller is usable. **However, `state.isLoadingMore` stays `true`** (minor R1). | **OK** (minor R1) |
| 7 | `results` are copied | `List<T>.of(page.results)` on replace; spread on append. The test fails on the pre-fix code; mutation r5 is killed. | **OK** |
| 8 | `PageRequest.checked` throws `ArgumentError` in release too, on every path that builds a request | `page.dart:7-15` uses explicit `throw`s, not asserts. The `limit` test fails on the pre-fix code, and mutation r6 (unchecked constructor) is killed. **Only the constructor (`paging_controller.dart:25`) calls `.checked`.** `loadFirst` (`:57-58`), `refresh` (`:70`) and the next-page request (`:133`) use the plain constructor. They are safe by construction: `limit` is `final` and validated once, and each offset is either `0` or `request.offset + results.length`, which is ≥ 0. No path can build an invalid request. | **OK** (info R6) |
| 9 | Overlap semantics are documented | `paging_controller.dart:49-50, 61-63`: "the last one wins. The earlier fetches are not cancelled; their responses are dropped." | **OK** |
| 10 | No repeat search for an unchanged trimmed query | `debounced_query.dart:52-54`. The test fails on the pre-fix code; mutation q1 is killed. "Searched again after a clear" is also tested. | **OK** |
| 11 | A clear fires only after a search actually fired (approved spec change) | `_searched` is set inside the timer callback (`:55-58`). The replaced test now asserts `clears == 0` for type-then-delete within the delay. It fails on the pre-fix code, and mutation q2 (set `_searched` when scheduling instead of when firing) is killed, so the new behaviour is pinned. The case "a blank query after a fired search clears" is still asserted. This change is not a weakening. | **OK** |
| 12 | `update` after `dispose` does nothing | `_disposed` guard at `:39-41`. The test fails on the pre-fix code; mutation q3 is killed. | **OK** |
| 13 | `fake_async` replaces the real Timer, with no lock change | The real-`Timer` test is gone. The new test runs the *default* `_realTimer` under `fakeAsync`, with nothing at 299 ms and a fire at 300 ms. `fake_async 1.3.3` (sha256 `5368f2…`) is identical in `pubspec.lock` at `350e215` and at `b8d3abe`. The only new dependency is the `pub_deps//:fake_async` test dep in BUILD. `git diff origin/main b8d3abe -- pubspec.lock MODULE.bazel.lock MODULE.bazel` is **empty**, and `fvm dart pub get` leaves the tree clean. | **OK** |
| 14 | The purity glob and test catch a Flutter import | `_PURE_SRCS = glob(lib/**/*.dart, exclude the 2 scope files)` feeds both the library and the test data, and the test lists the directory. Probe: a new `lib/src/zz_verifier_probe.dart` importing `package:flutter/widgets.dart` makes `//utility/mc_media:purity_test` FAIL (`Actual: ['utility/mc_media/lib/src/zz_verifier_probe.dart']`). The probe file was removed afterwards. | **OK** |

### Mutations at b8d3abe ([diffs](verifier/reverify_mutations.md)); every one was restored and the tree is clean
- **Killed (22 of 25):**
  - **New behaviour:** r1, r3, r4a, r4b, r4d, r5, r6 (controller); q1–q4 (debounce); k1–k4 (history)
  - **Original mutations re-run, no regression:** re-m1 (end guard), re-m2 (in-flight guard), re-m3 (retry asks for page 1), re-m4 (retry appends without de-dup), re-m5 (stale guard), re-m7 (end check off by one), re-m9 (an `Exception` no longer mapped)
- **Survived (3):**
  - r2: the Error path clears `_inFlight` regardless of generation
  - r4c: no `_disposed` guard in `loadMore`
  - k5: no cap in `add`; `load` caps on the next read

  In all three, the real code behaves correctly; only the tests don't pin it (R2 to R4).

### Gates at b8d3abe
| Gate | Result |
|---|---|
| `test --nocache_test_results //...` | **60 / 60 pass**, all executed: 58 plus the 2 `mc_test_steps` targets from the merge |
| `build --config=lint //...` | `Build completed successfully` |
| `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| `tool/rules_fork.sh check` | `ai_rules_dart: 3 patch(es) apply strictly on pin e7163aab8f91` (0003 comes from T-0029 on main); `ai_rules_flutter: queue empty, OK` |
| `fvm dart format … utility/mc_paging utility/mc_media utility/mc_fixtures_media` | `24 files (0 changed)`. Repo-wide, only `tool/loc/**` and T-0029 evidence `.dart` files would change; both come from main, not T-0030. |
| Coverage (own parser, union of LCOV) | **`mc_paging` 116/116 = 100 %** (`page` 18, `paging_controller` 57, `debounced_query` 20, `search_history` 21); **`mc_media` 21/21 = 100 %** |
| AC7 closure check | `PASS`: `mc_paging` 2918 targets and `mc_media` 1107, no markers; the positive control shows Flutter |
| AC7 negative control (`@pub_deps//:flutter` added to the pure `:mc_media`) | exit 1, `mc_media` 2298 targets, `pub_deps__flutter//:flutter`; result **FAIL T-0030-AC7** |
| AC6 dependents | `git diff origin/main b8d3abe` over `mc_fixtures_characters/`, `mc_api_client/` and `bundled_image_resolver_test.dart` is empty; all pass in the uncached run |

### Merge commit f5c6ca5 (parents `b53b963` and `c14706e` = `origin/main`)
- `git show --remerge-diff f5c6ca5` is **empty**: the merge resolved no conflicts by hand.
- Against its `origin/main` parent, the merge result differs outside the T-0030 paths in only two files:
  - `pubspec.yaml`: the two workspace lines, `utility/mc_media` and `utility/mc_paging`
  - the T-0030 task file
- Nothing unrelated came in. `b8d3abe` after the merge touches only T-0030 engineer evidence and the task file.

### Test integrity in the fix round
- Four old test names are gone, and each one is replaced:
  - "the pure mc_media library imports no Flutter" becomes the glob version. It is stronger: every file is scanned, and the test requires at least 3.
  - "clearing while a search is pending cancels it" becomes "deleting text … no clear". This is the approved spec change, pinned by q2.
  - "the default timer is a real Timer" becomes the `fakeAsync` version. It is stronger: it asserts both the 299 ms and the 300 ms boundary.
  - "an unreadable store is a failure" becomes "a corrupt file loads as empty and add heals it". This follows the TL decision, and the new test asserts more.
- There is no `skip:`, `solo:`, `// ignore` or hand-written `mixin` in the fix-round diff.

### Issues at b8d3abe (none blocking)
- **R1 (minor)** `utility/mc_paging/lib/src/paging_controller.dart:111-118`: when an `Error` propagates, no state is emitted, so `state.isLoadingMore` stays `true` (the probe printed `isLoadingMore after Error: true`). The UI would keep showing a spinner until the next call. Fix: emit `copyWith(isLoadingMore: false)` before `rethrow` when the generation matches, and assert it in the Error test.
- **R2 (minor, test gap)** `paging_controller.dart:76`: nothing pins the `_disposed` guard in `loadMore`. The test "every entry point does nothing after dispose" calls `loadMore` while a failure is set, and the failure guard already blocks it, so mutation r4c survives. Fix: call `loadMore` after dispose in a healthy state.
- **R3 (minor, test gap)** `paging_controller.dart:114`: nothing pins the generation check on the Error path, so mutation r2 survives. The case is a stale `Error` arriving while a newer `refresh` is in flight: it must not let `loadMore` start a parallel request. My probe shows the real code is correct.
- **R4 (minor, test gap)** `utility/mc_paging/lib/src/query/search_history.dart:50`: nothing pins `add`'s own `take(cap)`, because `load` caps on read, so mutation k5 survives. Without it, `add` would return a list longer than the cap and the file would grow without bound. Fix: assert the length of `add`'s return value in the 12-query test.
- **R5 (minor, doc)** `paging_controller.dart:6`: the `PageFetcher` doc still says "A thrown error is mapped with `ApiFailure.from`". Only an `Exception` is mapped now; an `Error` propagates.
- **R6 (info)** Item 8: `.checked` is called only in the constructor (`paging_controller.dart:25`). The other three request builders are safe by construction, as explained in the items table.
- **R7 (info)** `documents/tasks/T-0030-paging-and-media-kits.md:66` still says `mc_paging` coverage is "98/98". It is now 116/116, which the engineer's `coverage.txt` shows correctly.

The earlier issues 1 to 5 from the first round are resolved by fix items 13, 4, 2, 3, and 5/8/12.
