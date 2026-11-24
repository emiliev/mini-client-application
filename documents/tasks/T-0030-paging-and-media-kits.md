# T-0030: `mc_paging` and `mc_media` kits (P1-14 subset, U14, U19)

| Field | Value |
|---|---|
| Status | In Verification |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0030-paging-and-media` |
| Created | 2026-11-25 |
| Depends on | T-0017 to T-0026 (foundation, `mc_bloc_kit`, `mc_api_errors`, `mc_storage`, `mc_test_utils`) |
| Related | [plan 01 §3.2, U14, U19, P1-14](../plan/01-architecture-and-modules.md), [plan 05](../plan/05-testing-and-bdd.md), ADR-0007, ADR-0010, R30, F-0025 |

## Goal
The two utility kits that the list-detail archetype (LD) needs before the first Marvel feature, `characters_list` (P1-17), can be built. The design-system lists and media widgets (P1-12 subset) build on them next.

## Scope
- **In:**
  - `utility/mc_paging` (archetype UK, layout as in plan 01 §3.2). It depends on `mc_prelude`, `mc_bloc_kit`, `mc_api_errors` and, for search history only, `mc_storage`.
    - `PagedState<T>`: freezed, with `@Freezed(...)` flags per R30 only if JSON is needed. It holds the loaded items, `PageRequest` (offset and limit), `hasReachedEnd`, `isLoadingMore`, an optional failure (an `McFailure` from `mc_api_errors`) and `total`.
    - `PagingController<T>`: a helper used *by* an `McBloc`, with no mixins (plan 01 line 39, cutoff-critical kits). It has `loadFirst`, `loadMore`, `refresh`, and `retry` after a failure. It is generic over a `Future<Result<Page<T>>> Function(PageRequest)` fetcher.
    - `Page<T>` matches the mocked backend's paging contract: `offset`, `limit`, `total` and `results`. See `mc_fixtures_characters/lib/src/handlers/characters_handlers.dart`.
    - `DebouncedQuery`: a debounce on a clock that tests can inject. No real timers in tests.
    - `SearchHistory` on top of `mc_storage`: most recent first, de-duplicated, capped.
  - `utility/mc_media` (archetype UD). It holds the `ApiImage` reference and the `ImageVariant` enum, the `McImageResolver` interface and `McMediaScope`, an `InheritedWidget` that provides the resolver.
    - `ApiImage` and `ImageVariant` move from `mc_fixtures_media` to `mc_media`. `mc_fixtures_media` keeps its `BundledImageResolver`, now `implements McImageResolver`, and re-exports `ApiImage` so existing imports keep working.
    - `mc_fixtures_characters` must still build and pass unchanged.
- **Out:** `McPagedGrid`, `McPagedList` and `McImage` widgets (the next task, P1-12 subset), facets, `mc_forms`, and `mc_analytics`.

## Acceptance criteria
- **T-0030-AC1:** Given a `PagingController` over a fake fetcher with 45 items and limit 20, when `loadFirst` and then `loadMore` run twice, then there are 3 requests with offsets 0, 20 and 40, 45 items in order, and `hasReachedEnd` is true.
- **T-0030-AC2:** Given `PagedState` at its end, when `loadMore` is called, then no request is made. Given a `loadMore` in flight, when `loadMore` is called again, then no second request is made. (P1-14 AC2.)
- **T-0030-AC3:** Given a failing second page, then the state keeps the first page's items and exposes the failure. When `retry` runs, then only the failed page is requested again and the items append once, with no duplicates.
- **T-0030-AC4:** Given a `DebouncedQuery` of 300 ms on a fake clock, when typing 5 characters in 200 ms, then exactly 1 search fires, with the final text. An empty or whitespace-only query after a non-empty one emits a clear, not a search. (P1-14 AC3.)
- **T-0030-AC5:** Given `SearchHistory` with cap 10 on an in-memory or temp-dir store, when the same query is added twice and 12 distinct queries are added, then it keeps the 10 most recent, de-duplicated, most recent first. The history survives a new `SearchHistory` instance on the same store.
- **T-0030-AC6:** Given `McMediaScope` with a resolver, then `McMediaScope.of(context)` returns it. Without a scope, `of` throws a `FlutterError` naming `McMediaScope`. `BundledImageResolver` is an `McImageResolver`. Everything that depended on `mc_fixtures_media` still builds and its tests pass unchanged (name them in the handoff).
- **T-0030-AC7:** Both packages are listed in the root `pubspec.yaml` workspace and carry the BUILD targets the existing utilities use, with analysis, format and tests. `mc_arch_check` passes. `mc_paging` is pure Dart: its closure contains no Flutter and no `sky_engine`, checked with `cquery` the way T-0023 checked `mc_api_client`. Each package has ≥ 90 % line coverage (ADR-0010). `test //...`, `build --config=lint //...` and `rules_fork.sh check` are green.

## Notes for the Engineer
- Read `CLAUDE.md`, `documents/STATUS.md`, `documents/fleet/protocol.md`, ADR-0007, ADR-0010 and plan 01 §3.2. Copy the package shape, BUILD macros and test style from `utility/mc_bloc_kit` and `utility/mc_api_errors`. Tests are solitary: AAA, with `sut`.
- Every Bazel command uses `tool/bazelw --output_base=/tmp/mc-ob-T-0030-engineer`.
- No mixins in `mc_paging`.
- Evidence scripts must FAIL when they can't prove the claim. Every recent Verifier broke a build on purpose to check this.
- Commit WIP often, because usage limits can stop you mid-task. Rebase onto `origin/main` before handoff (P-036). Other branches are changing `MODULE.bazel.lock` and the root `pubspec.lock`: re-resolve them, don't hand-merge.
- Findings start at F-0029.

## Log
- 2026-11-25: Created and dispatched (TL).
- 2026-11-25: Engineer: `mc_media` (pure `:mc_media` + Flutter `:mc_media_scope`), `mc_paging` (freezed `PagedState`, `PagingController`, `DebouncedQuery`, `SearchHistory`), `mc_fixtures_media` implements `McImageResolver`. First cut with one Flutter `mc_media` library broke `//utility/mc_api_client:api_client_test` (pure test reaching Flutter through the fixtures chain), so it was split (F-0029). Handoff.
- 2026-11-25: Fix round (TL items 1 to 14): SearchHistory (serialised clear, self-healing corrupt store, cap on load, one-instance-per-key doc), PagingController (disposed guards, Errors propagate, copied results, ArgumentError for bad limit/offset, last-wins doc), DebouncedQuery (no repeat search, clear only after a fired search, dead after dispose, fake_async), mc_media purity test scans a glob. Spec change approved by the TL: typing and deleting inside the delay now emits no clear (test renamed accordingly). Evidence: `evidence/T-0030/engineer/fixround-tests-fail-without-fix.txt`. T-0029 merged into the branch; locks unchanged after re-resolve.

## Outcome
**Handed off** for verification on `fleet/T-0030-paging-and-media`. Evidence: `documents/evidence/T-0030/engineer/`.

### AC to test map
| AC | Tests (name contains the ID) |
|---|---|
| AC1 | `//utility/mc_paging:paging_controller_test` (group "T-0030-AC1 loading pages"), `paged_state_test` (Page, PageRequest) |
| AC2 | `paging_controller_test` (guards, stale responses), `paged_state_test` (defaults, equality) |
| AC3 | `paging_controller_test` (group "T-0030-AC3 failures": keeps page one, retry appends once, first-page and refresh failure, throwing fetcher) |
| AC4 | `//utility/mc_paging:debounced_query_test` (fake clock, no real timers; one test uses the default real `Timer` for 1 ms to cover the default factory) |
| AC5 | `//utility/mc_paging:search_history_test` (temp-dir `FileStore`) |
| AC6 | `//utility/mc_media:media_scope_test`, `api_image_test`, `//utility/mc_fixtures_media:media_contract_test`. Unchanged and passing: `mc_fixtures_media:bundled_image_resolver_test`, `mc_fixtures_characters:characters_test`, `provider_contract_test`, `mc_api_client:api_client_test` |
| AC7 | `//utility/mc_paging:purity_test`, `//utility/mc_media:purity_test`, `tool/checks/T-0030-AC7_closure.sh` ([report](../evidence/T-0030/engineer/AC7_closure.md), [negative control](../evidence/T-0030/engineer/AC7_negative_control.md)), gates below |

### Gates (logs in the evidence directory)
`test //...` 60/60 pass (`gate-test.log`); `build --config=lint //...` green (`gate-lint.log`); `mc_arch_check` OK (`gate-arch.log`); `rules_fork.sh check` OK (`gate-rules-fork.log`); `dart format` clean. Coverage (union of per-target LCOV, `merge_lcov.py`, `coverage.txt`): `mc_paging` 98/98 = 100 %, `mc_media` 21/21 = 100 %.

### Root changes
`pubspec.yaml` workspace: `utility/mc_media`, `utility/mc_paging`. `pubspec.lock` re-resolved with `fvm dart pub get` (no new third-party packages; `freezed_annotation 3.1.0` was already locked). `MODULE.bazel.lock` unchanged.

### Deviations and decisions for the TL
1. **`mc_media` has two Bazel libraries and two barrels** (`mc_media.dart` pure, `mc_media_scope.dart` Flutter), see [F-0029](../findings/F-0029-mc-media-split-pure-and-flutter.md). `McMediaScope` is imported from `package:mc_media/mc_media_scope.dart`.
2. **`ResolvedImage` has no `ImageProvider`** (it would make the pure library Flutter). `BundledImageResolver` implements `McImageResolver`; `BundledImage` implements `ResolvedImage` and keeps `assetKey`. P1-12 `McImage` decides the provider.
3. **`mc_paging` does not depend on `mc_bloc_kit`** (nothing to import; the controller takes an `onState` callback). Fetcher type is `Future<Result<Page<T>, ApiFailure>>` (the task's "McFailure" is `ApiFailure`; `Result` takes two type parameters).
4. **Generated `mixin _$PagedState`** comes from freezed (F-0029 item 5). `purity_test` checks hand-written sources only.
5. No tests deleted, skipped or weakened; no `// ignore:`. `mc_fixtures_media` gained one test file and `BundledImageResolver` / `BundledImage` gained `implements` plus `@override` only. `mc_fixtures_media` coverage was not measured (flutter_test coverage emits no lib entries for it; it is outside the 90 % scope of this task).

### Follow-ups
P1-12: `McImage` and a `ResolvedImage` to `ImageProvider` bridge; `McPagedList` / `McPagedGrid` over `PagedState`; DI initializer for `mc_paging` if the plan's `McPagingDIInitializer` is still wanted (nothing registers yet, so none was added).
